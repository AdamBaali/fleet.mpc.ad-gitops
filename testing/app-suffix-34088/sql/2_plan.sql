-- =====================================================================
-- 2_plan.sql: build the cleanup plan
--
-- Changes NO Fleet table. Creates one helper table, zz_app_suffix_map,
-- that 3_apply_batch.sql reads. Nothing in Fleet reads it. Re-running this
-- file rebuilds the plan from scratch.
--
-- Run on the primary with the mysql client, after 1_diagnose.sql CHECK 4
-- showed unexplained = 0:
--   mysql ... fleet < 2_plan.sql
-- =====================================================================

-- Fleet's tables use utf8mb4_unicode_ci. MySQL 8 clients default to
-- utf8mb4_0900_ai_ci, which makes comparisons with the variables below fail.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- INSERT ... SELECT under the default REPEATABLE READ locks every software
-- row it reads, which blocks Fleet's software ingestion while it runs.
-- READ COMMITTED doesn't. It needs binlog_format ROW or MIXED, or the
-- binary log off (the default on Amazon Aurora MySQL 3).
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

SET @online_hours = 24;

-- Bundle IDs left out of the cleanup because Fleet still produces their
-- ".app" names (1_diagnose.sql CHECK 3). Firefox is sent as "Firefox.app"
-- by the macos_firefox detail query on hosts with the parse_ini table, so
-- merging its rows would be undone on the next software report. Add any
-- other bundle ID that CHECK 3 lists. Comma separated, no spaces.
SET @exclude_bundle_ids = 'org.mozilla.firefox';

-- Rows per batch. Each run of 3_apply_batch.sql handles one batch in one
-- transaction.
SET @batch_size = 100;

DROP TABLE IF EXISTS zz_app_suffix_map;
CREATE TABLE zz_app_suffix_map (
  stale_id        BIGINT UNSIGNED NOT NULL,
  kind            VARCHAR(16)  NOT NULL,
  pair_by         VARCHAR(16)  NOT NULL DEFAULT 'none',
  stale_name      VARCHAR(255) NOT NULL,
  trimmed_name    VARCHAR(255) NOT NULL,
  target_checksum BINARY(16)   NOT NULL,
  survivor_id     BIGINT UNSIGNED NULL,
  batch_no        INT UNSIGNED NOT NULL DEFAULT 0,
  state           VARCHAR(20)  NOT NULL DEFAULT 'pending',
  PRIMARY KEY (stale_id),
  KEY idx_batch_state (batch_no, state),
  KEY idx_survivor (survivor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Pass 1 (kind 'suffix'): rows whose name still ends in ".app"
--
-- In scope: a macOS app row whose name ends in ".app", that still has host
-- links, none of them to an online host, whose bundle ID is not excluded,
-- and whose stored checksum matches the formula. The last condition proves
-- the SQL formula reproduces Fleet's checksum for that exact row.
--
-- Left out on purpose:
--   - rows linked to online hosts: still being produced, would come back
--   - rows with no links: Fleet's vulnerabilities cron deletes them
-- ---------------------------------------------------------------------
INSERT INTO zz_app_suffix_map (stale_id, kind, stale_name, trimmed_name, target_checksum)
SELECT s.id, 'suffix', s.name, LEFT(s.name, CHAR_LENGTH(s.name) - 4),
       UNHEX(MD5(CONCAT_WS(CHAR(0),
         s.version, s.source, COALESCE(s.bundle_identifier, ''), s.`release`,
         s.arch, s.vendor, s.extension_for, s.extension_id,
         LEFT(s.name, CHAR_LENGTH(s.name) - 4),
         NULLIF(s.application_id, ''), NULLIF(s.upgrade_code, ''))))
FROM software s
WHERE s.source = 'apps'
  AND s.name LIKE '%.app'
  AND CHAR_LENGTH(s.name) > 4
  AND NOT FIND_IN_SET(COALESCE(s.bundle_identifier, ''), @exclude_bundle_ids)
  AND s.checksum = UNHEX(MD5(CONCAT_WS(CHAR(0),
        s.version, s.source, COALESCE(s.bundle_identifier, ''), s.`release`,
        s.arch, s.vendor, s.extension_for, s.extension_id, s.name,
        NULLIF(s.application_id, ''), NULLIF(s.upgrade_code, ''))))
  AND EXISTS (SELECT 1 FROM host_software hs WHERE hs.software_id = s.id)
  AND NOT EXISTS (
    SELECT 1 FROM host_software hs
    JOIN host_seen_times hst ON hst.host_id = hs.host_id
    WHERE hs.software_id = s.id
      AND hst.seen_time >= NOW() - INTERVAL @online_hours HOUR);

-- Rows already in the plan can't be anyone's survivor. Otherwise "X.app.app"
-- could pair with "X.app", and both would be deleted.
DROP TEMPORARY TABLE IF EXISTS zz_stale_ids;
CREATE TEMPORARY TABLE zz_stale_ids (id BIGINT UNSIGNED NOT NULL PRIMARY KEY);
INSERT INTO zz_stale_ids SELECT stale_id FROM zz_app_suffix_map;

-- Pair each row with its correctly named twin, found by checksum exactly
-- as ingestion finds it. 3_apply_batch.sql pairs again before each batch,
-- because a host can report the twin in between.
UPDATE zz_app_suffix_map m
JOIN software c ON c.checksum = m.target_checksum
LEFT JOIN zz_stale_ids x ON x.id = c.id
SET m.survivor_id = c.id, m.pair_by = 'checksum'
WHERE x.id IS NULL;

-- No checksum twin: the row hosts report today may have another name.
-- Fleet now names apps from the bundle's display name or bundle name
-- before the file name, so "Visual Studio Code.app" is reported as "Code".
-- Fall back to the one row with the same bundle ID, version and other
-- identity columns that hosts still use. Only when there's exactly one
-- candidate: apps that share a bundle ID (for example helper apps) have
-- several, and those are left alone.
DROP TEMPORARY TABLE IF EXISTS zz_bundle_twins;
CREATE TEMPORARY TABLE zz_bundle_twins (
  stale_id    BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  survivor_id BIGINT UNSIGNED NOT NULL
);
INSERT INTO zz_bundle_twins
SELECT m.stale_id, MIN(o.id)
FROM zz_app_suffix_map m
JOIN software s ON s.id = m.stale_id
JOIN software o
  ON o.bundle_identifier = s.bundle_identifier
 AND o.version = s.version AND o.source = s.source AND o.`release` = s.`release`
 AND o.arch = s.arch AND o.vendor = s.vendor
 AND o.extension_for = s.extension_for AND o.extension_id = s.extension_id
 AND o.id <> s.id
LEFT JOIN zz_stale_ids x ON x.id = o.id
WHERE m.survivor_id IS NULL
  AND s.bundle_identifier <> ''
  AND o.name NOT LIKE '%.app'
  AND x.id IS NULL
  AND EXISTS (SELECT 1 FROM host_software hs WHERE hs.software_id = o.id)
GROUP BY m.stale_id
HAVING COUNT(*) = 1;

UPDATE zz_app_suffix_map m
JOIN zz_bundle_twins t ON t.stale_id = m.stale_id
SET m.survivor_id = t.survivor_id, m.pair_by = 'bundle';

-- ---------------------------------------------------------------------
-- Pass 2 (kind 'duplicate'): same-name duplicate versions
--
-- On Fleet Premium, the hourly Fleet-maintained app job
-- (ReconcileMaintainedAppSoftwareNames) renames software rows to the
-- catalog name, for example "Zoom.app" to "Zoom", and keeps the checksum
-- of the name the host reported. A ".app" row renamed this way no longer
-- ends in ".app". It shows up as a second row with the same name and
-- version as the row hosts report today.
--
-- A duplicate group is two or more macOS app rows with the same name,
-- version and other identity columns. In each group, the survivor is the
-- row hosts use: a row with links first, then the most online hosts, then
-- the row whose checksum matches its name, then the lowest id. Other rows
-- in the group are merged into it only if none of their hosts are online.
-- Rows that online hosts still use are left alone: those hosts would
-- recreate them. Checksums are never recomputed in this pass.
--
-- Rows still ending in ".app" are left to pass 1.
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS zz_dup_groups;
CREATE TEMPORARY TABLE zz_dup_groups (grp BINARY(16) NOT NULL PRIMARY KEY);
INSERT INTO zz_dup_groups
SELECT UNHEX(MD5(CONCAT_WS(CHAR(0),
         version, source, COALESCE(bundle_identifier, ''), `release`, arch, vendor,
         extension_for, extension_id, name,
         NULLIF(application_id, ''), NULLIF(upgrade_code, '')))) AS grp
FROM software
WHERE source = 'apps' AND name NOT LIKE '%.app'
  AND NOT FIND_IN_SET(COALESCE(bundle_identifier, ''), @exclude_bundle_ids)
GROUP BY grp
HAVING COUNT(*) > 1;

DROP TEMPORARY TABLE IF EXISTS zz_dup_rows;
CREATE TEMPORARY TABLE zz_dup_rows (
  id           BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  grp          BINARY(16) NOT NULL,
  checksum     BINARY(16) NOT NULL,
  canonical    TINYINT NOT NULL,
  links        INT NOT NULL,
  online_links INT NOT NULL,
  KEY idx_grp (grp)
);

INSERT INTO zz_dup_rows (id, grp, checksum, canonical, links, online_links)
SELECT s.id, g.grp, s.checksum, s.checksum = g.grp,
       (SELECT COUNT(*) FROM host_software hs WHERE hs.software_id = s.id),
       (SELECT COUNT(*) FROM host_software hs
          JOIN host_seen_times hst ON hst.host_id = hs.host_id
         WHERE hs.software_id = s.id
           AND hst.seen_time >= NOW() - INTERVAL @online_hours HOUR)
FROM software s
JOIN zz_dup_groups g ON g.grp = UNHEX(MD5(CONCAT_WS(CHAR(0),
         s.version, s.source, COALESCE(s.bundle_identifier, ''), s.`release`, s.arch, s.vendor,
         s.extension_for, s.extension_id, s.name,
         NULLIF(s.application_id, ''), NULLIF(s.upgrade_code, ''))))
WHERE s.source = 'apps' AND s.name NOT LIKE '%.app';

DROP TEMPORARY TABLE IF EXISTS zz_dup_survivors;
CREATE TEMPORARY TABLE zz_dup_survivors (
  grp         BINARY(16) NOT NULL PRIMARY KEY,
  survivor_id BIGINT UNSIGNED NOT NULL,
  checksum    BINARY(16) NOT NULL
);

INSERT INTO zz_dup_survivors (grp, survivor_id, checksum)
SELECT grp, id, checksum FROM (
  SELECT grp, id, checksum,
         ROW_NUMBER() OVER (PARTITION BY grp
                            ORDER BY (links > 0) DESC, online_links DESC, canonical DESC, id) AS rn
  FROM zz_dup_rows
) r
WHERE rn = 1;

-- Pass 1 survivors are never merged away here.
DROP TEMPORARY TABLE IF EXISTS zz_pass1_survivors;
CREATE TEMPORARY TABLE zz_pass1_survivors (id BIGINT UNSIGNED NOT NULL PRIMARY KEY);
INSERT IGNORE INTO zz_pass1_survivors
SELECT survivor_id FROM zz_app_suffix_map WHERE survivor_id IS NOT NULL;

INSERT IGNORE INTO zz_app_suffix_map
  (stale_id, kind, pair_by, stale_name, trimmed_name, target_checksum, survivor_id)
SELECT d.id, 'duplicate', 'group', s.name, s.name, v.checksum, v.survivor_id
FROM zz_dup_rows d
JOIN zz_dup_survivors v ON v.grp = d.grp
JOIN software s ON s.id = d.id
LEFT JOIN zz_pass1_survivors p ON p.id = d.id
WHERE d.id <> v.survivor_id
  AND d.links > 0
  AND d.online_links = 0
  AND p.id IS NULL;

-- Number the batches.
DROP TEMPORARY TABLE IF EXISTS zz_batches;
CREATE TEMPORARY TABLE zz_batches (stale_id BIGINT UNSIGNED NOT NULL PRIMARY KEY, batch_no INT UNSIGNED NOT NULL);
INSERT INTO zz_batches
SELECT stale_id, FLOOR((ROW_NUMBER() OVER (ORDER BY stale_id) - 1) / @batch_size)
FROM zz_app_suffix_map;
UPDATE zz_app_suffix_map m JOIN zz_batches b ON b.stale_id = m.stale_id SET m.batch_no = b.batch_no;

-- ---------------------------------------------------------------------
-- The plan. Share this output before running 3_apply_batch.sql.
-- merge:  hosts move to survivor_id, the stale row is deleted
-- rename: the ".app" row keeps its id and hosts, gets the trimmed name
--         and the matching checksum
-- pair_by says how the survivor was found: checksum, bundle (same bundle
-- ID and version, one candidate), or group (same-name duplicate).
-- ---------------------------------------------------------------------
SELECT kind, pair_by, IF(survivor_id IS NULL, 'rename', 'merge') AS action,
       COUNT(*) AS software_rows,
       MAX(batch_no) + 1 AS batches
FROM zz_app_suffix_map
GROUP BY kind, pair_by, action
ORDER BY kind, pair_by, action;

SELECT m.stale_id, m.kind, m.pair_by, m.stale_name, m.trimmed_name, s.version, s.bundle_identifier,
       IF(m.survivor_id IS NULL, 'rename', 'merge') AS action, m.survivor_id, v.name AS survivor_name,
       (SELECT COUNT(*) FROM host_software hs WHERE hs.software_id = m.stale_id) AS host_links
FROM zz_app_suffix_map m
JOIN software s ON s.id = m.stale_id
LEFT JOIN software v ON v.id = m.survivor_id
ORDER BY host_links DESC
LIMIT 200;
