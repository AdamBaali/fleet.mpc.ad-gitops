-- =====================================================================
-- 2_execute.sql
-- .app suffix cleanup - execute
--
-- PRECONDITIONS
--   - 0_preflight.sql run and clean (version >= 4.82.0, CHECK 2 and
--     CHECK 4 both returned 0 rows)
--   - 1_preview.sql run, output reviewed and agreed, zz_app_suffix_map
--     still present and not rebuilt since
--   - database snapshot taken
--   - maintenance window, Fleet running (this is designed to run
--     alongside live ingestion, not against a stopped instance)
--
-- This mirrors Datastore.mergeSoftwareRow in
-- server/datastore/mysql/software.go, which is how Fleet merges
-- duplicate software rows internally. Same order, same collision
-- handling, same batching.
--
-- Everything is batched and idempotent. If you stop partway, re-run
-- from the top; completed rows are marked 'done' and skipped.
--
-- Run against the primary.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 0: undo trail
--
-- host_software rows are deleted or repointed and cannot be
-- reconstructed from Fleet afterwards. Capture them first.
-- 3_rollback.sql reads these.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_host_software (
  host_id     INT UNSIGNED    NOT NULL,
  software_id BIGINT UNSIGNED NOT NULL,
  last_opened_at TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (host_id, software_id)
) ENGINE=InnoDB;

INSERT IGNORE INTO zz_app_suffix_bak_host_software (host_id, software_id, last_opened_at)
SELECT hs.host_id, hs.software_id, hs.last_opened_at
FROM host_software hs
JOIN zz_app_suffix_map m ON m.stale_id = hs.software_id
WHERE m.state = 'pending';

CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_software AS
SELECT s.* FROM software s
JOIN zz_app_suffix_map m ON m.stale_id = s.id
WHERE m.state = 'pending';

CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_titles AS
SELECT t.id, t.name
FROM software_titles t
WHERE t.source = 'apps'
  AND t.name LIKE '%.app'
  AND CHAR_LENGTH(t.name) > 4;

-- ---------------------------------------------------------------------
-- STEP 1: preserve last_opened_at
--
-- Where a host is linked to both rows, the stale link is about to be
-- deleted. Fleet's internal merge simply drops it. That silently
-- discards a more recent last_opened_at, which feeds the "not used in
-- N days" reporting people build on top of software inventory.
--
-- Roll the newer value onto the survivor before dropping anything.
-- ---------------------------------------------------------------------
UPDATE host_software surv
JOIN zz_app_suffix_map m  ON m.survivor_id = surv.software_id
JOIN host_software stale  ON stale.host_id = surv.host_id
                         AND stale.software_id = m.stale_id
SET surv.last_opened_at = stale.last_opened_at
WHERE m.state = 'pending'
  AND stale.last_opened_at IS NOT NULL
  AND (surv.last_opened_at IS NULL
       OR stale.last_opened_at > surv.last_opened_at);

-- ---------------------------------------------------------------------
-- STEP 2: drop colliding host_software links
--
-- host_software has PK (host_id, software_id). A host linked to both
-- rows cannot have the stale link repointed, it would collide. Delete
-- the redundant stale link instead.
--
-- Not UPDATE IGNORE: skipped rows still count against LIMIT, so a
-- batched loop would terminate early and strand movable links.
--
-- REPEAT until 0 rows affected.
-- ---------------------------------------------------------------------
DELETE hs FROM host_software hs
JOIN zz_app_suffix_map m ON m.stale_id = hs.software_id
WHERE m.state = 'pending'
  AND EXISTS (
    SELECT 1 FROM (SELECT host_id, software_id FROM host_software) surv
     WHERE surv.host_id = hs.host_id
       AND surv.software_id = m.survivor_id
  )
LIMIT 1000;

-- ---------------------------------------------------------------------
-- STEP 3: repoint the remaining host_software links
--
-- REPEAT until 0 rows affected.
-- ---------------------------------------------------------------------
UPDATE host_software hs
JOIN zz_app_suffix_map m ON m.stale_id = hs.software_id
SET hs.software_id = m.survivor_id
WHERE m.state = 'pending'
LIMIT 1000;

-- ---------------------------------------------------------------------
-- STEP 4: repoint installed paths
--
-- No unique (host_id, software_id) here, so this cannot collide.
--
-- REPEAT until 0 rows affected.
-- ---------------------------------------------------------------------
UPDATE host_software_installed_paths p
JOIN zz_app_suffix_map m ON m.stale_id = p.software_id
SET p.software_id = m.survivor_id
WHERE m.state = 'pending'
LIMIT 1000;

-- ---------------------------------------------------------------------
-- STEP 5: clear derived rows for the stale ids
--
-- Neither table has a foreign key to software, so deleting the software
-- row leaves these behind. Fleet's orphan crons do eventually sweep
-- them, but stale software_cve rows keep reporting vulnerabilities
-- against software nobody has until that runs.
--
-- REPEAT each until 0 rows affected.
-- ---------------------------------------------------------------------
DELETE cve FROM software_cve cve
JOIN zz_app_suffix_map m ON m.stale_id = cve.software_id
WHERE m.state = 'pending'
LIMIT 1000;

DELETE shc FROM software_host_counts shc
JOIN zz_app_suffix_map m ON m.stale_id = shc.software_id
WHERE m.state = 'pending'
LIMIT 1000;

-- ---------------------------------------------------------------------
-- STEP 6: delete the stale software rows
--
-- software_cpe cascades (FK ON DELETE CASCADE). Everything else was
-- handled above.
--
-- REPEAT until 0 rows affected.
-- ---------------------------------------------------------------------
DELETE s FROM software s
JOIN zz_app_suffix_map m ON m.stale_id = s.id
WHERE m.state = 'pending'
  AND NOT EXISTS (SELECT 1 FROM (SELECT software_id FROM host_software) hs
                   WHERE hs.software_id = s.id)
LIMIT 1000;

-- Mark completed rows so a re-run skips them.
UPDATE zz_app_suffix_map m
SET m.state = 'done'
WHERE m.state = 'pending'
  AND NOT EXISTS (SELECT 1 FROM software s WHERE s.id = m.stale_id);

-- ---------------------------------------------------------------------
-- STEP 7: rename the titles
--
-- Safe in place, no checksum. The guard skips titles whose generated
-- unique_identifier falls back to the name, where a rename could
-- collide on idx_unique_sw_titles.
-- ---------------------------------------------------------------------
UPDATE software_titles t
SET t.name = LEFT(t.name, CHAR_LENGTH(t.name) - 4)
WHERE t.source = 'apps'
  AND t.name LIKE '%.app'
  AND CHAR_LENGTH(t.name) > 4
  AND (
    t.bundle_identifier IS NOT NULL
    OR t.application_id IS NOT NULL
    OR NOT EXISTS (
      SELECT 1 FROM (SELECT name, source, extension_for,
                            bundle_identifier, application_id
                       FROM software_titles) x
       WHERE x.name          = LEFT(t.name, CHAR_LENGTH(t.name) - 4)
         AND x.source        = t.source
         AND x.extension_for = t.extension_for
         AND x.bundle_identifier IS NULL
         AND x.application_id    IS NULL
    )
  );

-- ---------------------------------------------------------------------
-- STEP 8: team display name overrides
-- ---------------------------------------------------------------------
UPDATE software_title_display_names d
SET d.display_name = LEFT(d.display_name, CHAR_LENGTH(d.display_name) - 4)
WHERE d.display_name LIKE '%.app'
  AND CHAR_LENGTH(d.display_name) > 4;

-- ---------------------------------------------------------------------
-- STEP 9: verification
--
-- Expected:
--   remaining_stale_software  = count of 'unpaired' rows only
--   remaining_stale_titles    = 0, or only the collision-skipped ones
--   orphaned_host_software    = 0
--   pending_in_map            = 0
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM software
    WHERE source = 'apps' AND name LIKE '%.app'
      AND CHAR_LENGTH(name) > 4)                       AS remaining_stale_software,
  (SELECT COUNT(*) FROM software_titles
    WHERE source = 'apps' AND name LIKE '%.app'
      AND CHAR_LENGTH(name) > 4)                       AS remaining_stale_titles,
  (SELECT COUNT(*) FROM host_software hs
     LEFT JOIN software s ON s.id = hs.software_id
    WHERE s.id IS NULL)                                AS orphaned_host_software,
  (SELECT COUNT(*) FROM zz_app_suffix_map
    WHERE state = 'pending')                           AS pending_in_map,
  (SELECT COUNT(*) FROM zz_app_suffix_map
    WHERE state = 'unpaired')                          AS left_for_next_pass;

-- ---------------------------------------------------------------------
-- STEP 10: rebuild the counts
--
-- The Software page reads software_host_counts and
-- software_titles_host_counts, both of which are now stale. Numbers
-- will look wrong until the aggregation cron runs. Force it:
--
--   fleetctl trigger --name cleanups_then_aggregation
--
-- That also removes titles left with no software rows.
--
-- Vulnerability counts repopulate on the next vuln processing run.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- STEP 11: cleanup, once verified and settled
--
-- Keep the backup tables for at least one full vuln cycle before
-- dropping. They are the only rollback path.
--
--   DROP TABLE zz_app_suffix_bak_host_software;
--   DROP TABLE zz_app_suffix_bak_software;
--   DROP TABLE zz_app_suffix_bak_titles;
--   DROP TABLE zz_app_suffix_map;
-- ---------------------------------------------------------------------
