-- =====================================================================
-- 2_plan.sql: build the cleanup plan
--
-- Changes NO Fleet table. Creates one helper table, zz_app_suffix_map,
-- that 3_apply_batch.sql reads. Nothing in Fleet reads it. Re-running this
-- file rebuilds the plan from scratch.
--
-- Run on the primary, after 1_diagnose.sql CHECK 4 showed mismatched = 0.
-- =====================================================================

SET @online_hours = 24;

-- Bundle IDs left out of the cleanup because Fleet still produces their
-- ".app" names (1_diagnose.sql CHECK 3). Firefox is sent as "Firefox.app"
-- by the macos_firefox detail query on hosts with the parse_ini table, so
-- merging its rows would be undone within the hour. Add any other bundle
-- ID that CHECK 3 lists. Comma separated, no spaces.
SET @exclude_bundle_ids = 'org.mozilla.firefox';

-- Rows per batch. Each run of 3_apply_batch.sql handles one batch in one
-- transaction.
SET @batch_size = 100;

DROP TABLE IF EXISTS zz_app_suffix_map;
CREATE TABLE zz_app_suffix_map (
  stale_id        BIGINT UNSIGNED NOT NULL,
  stale_name      VARCHAR(255) NOT NULL,
  trimmed_name    VARCHAR(255) NOT NULL,
  target_checksum BINARY(16)   NOT NULL,
  survivor_id     BIGINT UNSIGNED NULL,
  batch_no        INT UNSIGNED NOT NULL DEFAULT 0,
  state           VARCHAR(16)  NOT NULL DEFAULT 'pending',
  PRIMARY KEY (stale_id),
  KEY idx_batch_state (batch_no, state),
  KEY idx_survivor (survivor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- In scope: a macOS app row whose name ends in ".app", that still has host
-- links, none of them to an online host, whose bundle ID is not excluded,
-- and whose stored checksum matches the formula. The last condition proves
-- the SQL formula reproduces Fleet's checksum for that exact row.
--
-- Left out on purpose:
--   - rows linked to online hosts: still being produced, would come back
--   - rows with no links: Fleet's vulnerabilities cron deletes them
INSERT INTO zz_app_suffix_map (stale_id, stale_name, trimmed_name, target_checksum)
SELECT s.id, s.name, LEFT(s.name, CHAR_LENGTH(s.name) - 4),
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

-- Pair each row with its correctly named twin, found by checksum exactly
-- as ingestion finds it. 3_apply_batch.sql pairs again before each batch,
-- because a host can report the twin in between.
UPDATE zz_app_suffix_map m
JOIN software c ON c.checksum = m.target_checksum
SET m.survivor_id = c.id;

-- Number the batches.
SET @n = -1;
UPDATE zz_app_suffix_map
SET batch_no = FLOOR((@n := @n + 1) / @batch_size)
ORDER BY stale_id;

-- ---------------------------------------------------------------------
-- The plan. Share this output before running 3_apply_batch.sql.
-- merge:  hosts move to survivor_id, the ".app" row is deleted
-- rename: the row keeps its id and hosts, gets the trimmed name and the
--         matching checksum
-- ---------------------------------------------------------------------
SELECT IF(survivor_id IS NULL, 'rename', 'merge') AS action,
       COUNT(*) AS software_rows,
       MAX(batch_no) + 1 AS batches
FROM zz_app_suffix_map
GROUP BY action;

SELECT m.stale_id, m.stale_name, m.trimmed_name, s.version, s.bundle_identifier,
       IF(m.survivor_id IS NULL, 'rename', 'merge') AS action, m.survivor_id,
       (SELECT COUNT(*) FROM host_software hs WHERE hs.software_id = m.stale_id) AS host_links
FROM zz_app_suffix_map m
JOIN software s ON s.id = m.stale_id
ORDER BY host_links DESC
LIMIT 200;
