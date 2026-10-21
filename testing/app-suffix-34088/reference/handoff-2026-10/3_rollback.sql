-- =====================================================================
-- 3_rollback.sql
-- .app suffix cleanup - rollback
--
-- Restores the state captured by 2_execute.sql STEP 0.
--
-- Only valid while the zz_app_suffix_bak_* tables still exist. A
-- database snapshot restore is always the cleaner option if one is
-- available and the window allows it; this exists for the case where
-- the cleanup went wrong but a full restore is too disruptive.
--
-- Caveats, stated plainly:
--   - Anything ingested since the cleanup is not rolled back. Hosts
--     that reported in the meantime will have correct links already.
--   - Deleted software_cve rows are not restored here. They repopulate
--     on the next vulnerability processing run.
--   - last_opened_at values rolled forward onto survivors in STEP 1 are
--     not reverted. They are strictly newer values, so this is not a
--     data loss.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 1: restore the software rows
-- ---------------------------------------------------------------------
INSERT IGNORE INTO software
SELECT * FROM zz_app_suffix_bak_software;

-- ---------------------------------------------------------------------
-- STEP 2: restore the host links
--
-- Repointed links are still sitting on the survivor id. Remove the ones
-- this cleanup created, then put the originals back.
-- ---------------------------------------------------------------------
DELETE hs FROM host_software hs
JOIN zz_app_suffix_map m ON m.survivor_id = hs.software_id
WHERE m.state = 'done'
  AND EXISTS (
    SELECT 1 FROM zz_app_suffix_bak_host_software b
     WHERE b.host_id = hs.host_id
       AND b.software_id = m.stale_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM zz_app_suffix_bak_host_software b2
     WHERE b2.host_id = hs.host_id
       AND b2.software_id = m.survivor_id
  );

INSERT IGNORE INTO host_software (host_id, software_id, last_opened_at)
SELECT host_id, software_id, last_opened_at
FROM zz_app_suffix_bak_host_software;

-- ---------------------------------------------------------------------
-- STEP 3: restore the title names
-- ---------------------------------------------------------------------
UPDATE software_titles t
JOIN zz_app_suffix_bak_titles b ON b.id = t.id
SET t.name = b.name;

-- ---------------------------------------------------------------------
-- STEP 4: reset the plan
-- ---------------------------------------------------------------------
UPDATE zz_app_suffix_map SET state = 'pending' WHERE state = 'done';

-- ---------------------------------------------------------------------
-- STEP 5: rebuild counts
--
--   fleetctl trigger --name cleanups_then_aggregation
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- STEP 6: verify
-- Expected: restored_software matches the backup row count.
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM zz_app_suffix_bak_software)     AS backup_software_rows,
  (SELECT COUNT(*) FROM software
     WHERE source = 'apps' AND name LIKE '%.app'
       AND CHAR_LENGTH(name) > 4)                       AS restored_software,
  (SELECT COUNT(*) FROM zz_app_suffix_bak_host_software) AS backup_host_links,
  (SELECT COUNT(*) FROM host_software hs
     JOIN zz_app_suffix_map m ON m.stale_id = hs.software_id) AS restored_host_links;
