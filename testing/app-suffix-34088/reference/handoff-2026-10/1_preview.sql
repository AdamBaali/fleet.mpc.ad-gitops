-- =====================================================================
-- 1_preview.sql
-- .app suffix cleanup - preview
--
-- Makes NO changes to any Fleet table.
--
-- It does create one helper table, zz_app_suffix_map, which holds the
-- plan. Nothing in Fleet reads that table. 2_execute.sql consumes it,
-- so preview and execute act on an identical, agreed row set rather
-- than each re-deriving scope at their own point in time.
--
-- Run against the primary. Share the output before running 2_execute.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 1: build the plan
--
-- A "stale" row is a macOS app whose name still carries the .app
-- suffix. Its "survivor" is the row with an identical identity in every
-- column except the name, where the name is the stale name minus the
-- four trailing characters.
--
-- CHAR_LENGTH, not LENGTH: LENGTH counts bytes in MySQL and would
-- mis-trim any app with a non-ASCII character in its name.
--
-- The identity columns below are exactly the ones Fleet feeds into
-- Software.ComputeRawChecksum, so two rows matching on all of them
-- differ only by name.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS zz_app_suffix_map;

CREATE TABLE zz_app_suffix_map (
  stale_id          BIGINT UNSIGNED NOT NULL,
  survivor_id       BIGINT UNSIGNED NULL,
  stale_name        VARCHAR(255)    NOT NULL,
  trimmed_name      VARCHAR(255)    NOT NULL,
  version           VARCHAR(255)    NOT NULL,
  bundle_identifier VARCHAR(255)    NULL,
  stale_hosts       INT             NOT NULL DEFAULT 0,
  survivor_hosts    INT             NOT NULL DEFAULT 0,
  colliding_hosts   INT             NOT NULL DEFAULT 0,
  state             VARCHAR(16)     NOT NULL DEFAULT 'pending',
  PRIMARY KEY (stale_id),
  KEY idx_survivor (survivor_id),
  KEY idx_state (state)
) ENGINE=InnoDB;

INSERT INTO zz_app_suffix_map
  (stale_id, survivor_id, stale_name, trimmed_name, version, bundle_identifier, state)
SELECT
  s.id,
  c.id,
  s.name,
  LEFT(s.name, CHAR_LENGTH(s.name) - 4),
  s.version,
  s.bundle_identifier,
  CASE WHEN c.id IS NULL THEN 'unpaired' ELSE 'pending' END
FROM software s
LEFT JOIN software c
       ON c.id                <> s.id
      AND c.name               = LEFT(s.name, CHAR_LENGTH(s.name) - 4)
      AND c.version            = s.version
      AND c.source             = s.source
      AND c.bundle_identifier <=> s.bundle_identifier
      AND c.`release`          = s.`release`
      AND c.arch               = s.arch
      AND c.vendor             = s.vendor
      AND c.extension_for      = s.extension_for
      AND c.extension_id       = s.extension_id
      AND c.application_id    <=> s.application_id
      AND c.upgrade_code      <=> s.upgrade_code
WHERE s.source = 'apps'
  AND s.name LIKE '%.app'
  AND CHAR_LENGTH(s.name) > 4;

-- Host counts, so the report shows what actually moves.
UPDATE zz_app_suffix_map m
SET m.stale_hosts = (
      SELECT COUNT(*) FROM host_software hs WHERE hs.software_id = m.stale_id
    ),
    m.survivor_hosts = (
      SELECT COUNT(*) FROM host_software hs WHERE hs.software_id = m.survivor_id
    ),
    m.colliding_hosts = (
      SELECT COUNT(*)
      FROM host_software a
      JOIN host_software b
        ON b.host_id = a.host_id
       AND b.software_id = m.survivor_id
      WHERE a.software_id = m.stale_id
    );

-- ---------------------------------------------------------------------
-- STEP 2: safety assertion
--
-- Every stale row must map to at most one survivor. The UNIQUE index on
-- software.checksum should guarantee this. If this returns anything,
-- STOP: preflight CHECK 4 was not clean and the plan is ambiguous.
-- ---------------------------------------------------------------------
SELECT 'AMBIGUOUS PAIRING - DO NOT PROCEED' AS warning,
       s.id AS stale_id, s.name, COUNT(*) AS candidate_survivors
FROM software s
JOIN software c
  ON c.id                <> s.id
 AND c.name               = LEFT(s.name, CHAR_LENGTH(s.name) - 4)
 AND c.version            = s.version
 AND c.source             = s.source
 AND c.bundle_identifier <=> s.bundle_identifier
WHERE s.source = 'apps'
  AND s.name LIKE '%.app'
  AND CHAR_LENGTH(s.name) > 4
GROUP BY s.id, s.name
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- STEP 3: summary
-- ---------------------------------------------------------------------
SELECT
  state,
  COUNT(*)                AS software_rows,
  SUM(stale_hosts)        AS host_links_to_move,
  SUM(colliding_hosts)    AS links_merged_into_existing,
  SUM(stale_hosts) - SUM(colliding_hosts) AS links_repointed
FROM zz_app_suffix_map
GROUP BY state;

-- ---------------------------------------------------------------------
-- STEP 4: the merges, largest first
--
-- Read this as: stale_name disappears, its hosts appear under
-- trimmed_name. Nothing is renamed.
-- ---------------------------------------------------------------------
SELECT
  stale_id, stale_name, version, bundle_identifier,
  survivor_id, trimmed_name,
  stale_hosts, survivor_hosts, colliding_hosts
FROM zz_app_suffix_map
WHERE state = 'pending'
ORDER BY stale_hosts DESC
LIMIT 100;

-- ---------------------------------------------------------------------
-- STEP 5: unpaired rows
--
-- No correctly named twin exists yet, so there is nothing to merge into.
-- These are deliberately LEFT ALONE.
--
-- Renaming them in SQL would desync software.checksum from the name, and
-- checksum is a UNIQUE key Fleet looks software up by. A row with a
-- stale checksum is invisible to ingestion, so the next report inserts
-- a duplicate instead of reusing it. Fleet's own source calls this out:
-- ComputeRawChecksum is the sole source of truth and must not be
-- reimplemented in SQL.
--
-- If a host still reports the app, ingestion creates the correct row
-- within the hour and the pair becomes mergeable on a later pass. If no
-- host reports it, the row is dead inventory that the orphan cleanup
-- cron removes on its own.
--
-- Re-run this file in a week; most of these will have paired up.
-- ---------------------------------------------------------------------
SELECT
  stale_id, stale_name, version, bundle_identifier, stale_hosts
FROM zz_app_suffix_map
WHERE state = 'unpaired'
ORDER BY stale_hosts DESC
LIMIT 100;

-- ---------------------------------------------------------------------
-- STEP 6: titles to rename
--
-- Titles are safe to rename in place. software_titles has no checksum
-- column, which is precisely why the original API-based script fixed
-- the Software titles tab but left the version rows untouched.
--
-- Excluded here: titles with no bundle_identifier and no application_id.
-- For those, the generated unique_identifier column falls back to the
-- name, so renaming can collide with an existing title on
-- idx_unique_sw_titles.
-- ---------------------------------------------------------------------
SELECT
  t.id, t.name AS current_name,
  LEFT(t.name, CHAR_LENGTH(t.name) - 4) AS new_name,
  t.bundle_identifier,
  CASE
    WHEN t.bundle_identifier IS NOT NULL OR t.application_id IS NOT NULL
      THEN 'rename'
    WHEN EXISTS (
      SELECT 1 FROM (SELECT id, name, source, extension_for,
                            bundle_identifier, application_id
                       FROM software_titles) x
       WHERE x.name          = LEFT(t.name, CHAR_LENGTH(t.name) - 4)
         AND x.source        = t.source
         AND x.extension_for = t.extension_for
         AND x.bundle_identifier IS NULL
         AND x.application_id    IS NULL
    ) THEN 'skip - would collide'
    ELSE 'rename'
  END AS action
FROM software_titles t
WHERE t.source = 'apps'
  AND t.name LIKE '%.app'
  AND CHAR_LENGTH(t.name) > 4
ORDER BY t.name
LIMIT 100;

-- ---------------------------------------------------------------------
-- STEP 7: team-level display name overrides
--
-- Separate table, separate fix. If anyone pinned a display name that
-- still carries the suffix, the UI shows it regardless of the title.
-- ---------------------------------------------------------------------
SELECT d.id, d.team_id, d.software_title_id, d.display_name
FROM software_title_display_names d
WHERE d.display_name LIKE '%.app'
  AND CHAR_LENGTH(d.display_name) > 4;
