-- =====================================================================
-- 3_apply_batch.sql: apply ONE batch of the plan
--
-- Mutating. Run it again until the last result shows pending = 0. Each
-- run is one transaction: a batch is either fully applied or not at all.
-- Safe to stop between runs and safe to re-run.
--
-- Run with the mysql client's default stop-on-error behavior (no --force).
-- If any statement fails, the client exits, the open transaction rolls
-- back, and the next run starts the same batch again.
--
-- Fleet keeps running. The steps follow how ingestion links hosts to
-- software (by name, then by checksum), so a host reporting during the
-- run converges on the same rows.
--
-- Before the first run: a database snapshot, and 2_plan.sql output
-- reviewed.
-- =====================================================================

SET @online_hours = 24;
SET @b = (SELECT MIN(batch_no) FROM zz_app_suffix_map WHERE state = 'pending');

-- Undo trail. host_software links cannot be rebuilt from Fleet once moved.
CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_software LIKE software;
CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_host_software LIKE host_software;
CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_paths LIKE host_software_installed_paths;

-- Re-check the batch against the live tables before touching it.
-- Gone: Fleet's own cleanup or ingestion already removed the row.
UPDATE zz_app_suffix_map m
LEFT JOIN software s ON s.id = m.stale_id
SET m.state = 'gone'
WHERE m.batch_no = @b AND m.state = 'pending' AND s.id IS NULL;

-- Online: a host linked to it came back and still sends the ".app" name.
UPDATE zz_app_suffix_map m
SET m.state = 'skip_online'
WHERE m.batch_no = @b AND m.state = 'pending'
  AND EXISTS (SELECT 1 FROM host_software hs
              JOIN host_seen_times hst ON hst.host_id = hs.host_id
              WHERE hs.software_id = m.stale_id
                AND hst.seen_time >= NOW() - INTERVAL @online_hours HOUR);

-- Pair again by checksum, since a host may have reported the twin since
-- 2_plan.sql ran.
UPDATE zz_app_suffix_map m
LEFT JOIN software c ON c.checksum = m.target_checksum
SET m.survivor_id = c.id
WHERE m.batch_no = @b AND m.state = 'pending';

START TRANSACTION;

INSERT IGNORE INTO zz_app_suffix_bak_software
SELECT s.* FROM software s
JOIN zz_app_suffix_map m ON m.stale_id = s.id
WHERE m.batch_no = @b AND m.state = 'pending';

INSERT IGNORE INTO zz_app_suffix_bak_host_software
SELECT hs.* FROM host_software hs
JOIN zz_app_suffix_map m ON m.stale_id = hs.software_id
WHERE m.batch_no = @b AND m.state = 'pending';

INSERT IGNORE INTO zz_app_suffix_bak_paths
SELECT p.* FROM host_software_installed_paths p
JOIN zz_app_suffix_map m ON m.stale_id = p.software_id
WHERE m.batch_no = @b AND m.state = 'pending';

-- ---------------------------------------------------------------------
-- MERGE rows (a correctly named twin exists)
-- ---------------------------------------------------------------------

-- A host linked to both rows keeps the twin's link. Carry the newer
-- last_opened_at over first, so "last opened" reports do not go back in
-- time.
UPDATE host_software surv
JOIN zz_app_suffix_map m ON m.survivor_id = surv.software_id
JOIN host_software st ON st.host_id = surv.host_id AND st.software_id = m.stale_id
SET surv.last_opened_at = st.last_opened_at
WHERE m.batch_no = @b AND m.state = 'pending'
  AND st.last_opened_at IS NOT NULL
  AND (surv.last_opened_at IS NULL OR st.last_opened_at > surv.last_opened_at);

-- Then drop the stale link. (host_id, software_id) is the primary key, so
-- it cannot be moved onto a link that already exists.
DELETE st FROM host_software st
JOIN zz_app_suffix_map m ON m.stale_id = st.software_id
JOIN host_software surv ON surv.host_id = st.host_id AND surv.software_id = m.survivor_id
WHERE m.batch_no = @b AND m.state = 'pending';

-- Move the remaining links.
UPDATE host_software hs
JOIN zz_app_suffix_map m ON m.stale_id = hs.software_id
SET hs.software_id = m.survivor_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

-- Installed paths have no unique key, so drop the paths the twin already
-- has before moving the rest. Otherwise the host shows the path twice.
DELETE p FROM host_software_installed_paths p
JOIN zz_app_suffix_map m ON m.stale_id = p.software_id
JOIN host_software_installed_paths q
  ON q.host_id = p.host_id AND q.software_id = m.survivor_id AND q.installed_path = p.installed_path
WHERE m.batch_no = @b AND m.state = 'pending';

UPDATE host_software_installed_paths p
JOIN zz_app_suffix_map m ON m.stale_id = p.software_id
SET p.software_id = m.survivor_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

-- software_cve and software_host_counts have no foreign key to software,
-- so they are cleared by hand. software_cpe and software_metadata cascade.
DELETE cve FROM software_cve cve
JOIN zz_app_suffix_map m ON m.stale_id = cve.software_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

DELETE shc FROM software_host_counts shc
JOIN zz_app_suffix_map m ON m.stale_id = shc.software_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

DELETE s FROM software s
JOIN zz_app_suffix_map m ON m.stale_id = s.id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- RENAME rows (no twin yet)
--
-- The name and the checksum change together, which is what Fleet's own
-- 4.75.0 migration (20251015103505) did. With both updated, ingestion
-- finds this row for every host: by name for hosts already linked, by
-- checksum for new hosts. Renaming without the checksum is what creates
-- duplicate versions.
--
-- If a host inserts the twin in the moment between pairing and this
-- statement, the unique checksum index rejects it, the client stops, and
-- the transaction rolls back. The next run pairs it as a merge.
-- ---------------------------------------------------------------------
UPDATE software s
JOIN zz_app_suffix_map m ON m.stale_id = s.id
SET s.name = m.trimmed_name, s.checksum = m.target_checksum
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NULL;

UPDATE zz_app_suffix_map
SET state = IF(survivor_id IS NULL, 'renamed', 'merged')
WHERE batch_no = @b AND state = 'pending';

COMMIT;

SELECT @b AS batch_applied, state, COUNT(*) AS software_rows
FROM zz_app_suffix_map
GROUP BY state
UNION ALL
SELECT @b, 'pending (total)', COUNT(*) FROM zz_app_suffix_map WHERE state = 'pending';
