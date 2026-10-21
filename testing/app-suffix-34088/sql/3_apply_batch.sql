-- =====================================================================
-- 3_apply_batch.sql: apply ONE batch of the plan
--
-- Mutating. Run it again until the last result shows pending = 0. Each
-- run is one transaction: a batch is either fully applied or not at all.
-- Safe to stop between runs and safe to re-run.
--
-- Run it with the mysql client, which stops at the first error:
--   mysql ... fleet < 3_apply_batch.sql
-- Never use --force, and don't run it in a GUI that continues after an
-- error. If a statement fails, the client exits, the open transaction
-- rolls back, and the next run starts the same batch again.
--
-- Fleet keeps running. The steps follow how ingestion links hosts to
-- software (by name, then by checksum), so a host reporting during the
-- run converges on the same rows.
--
-- The merge steps follow mergeDuplicateSoftware in Fleet's migration
-- 20260810160000_DedupeSoftwareChecksums (4.91.0), including reaching
-- host_software_installed_paths through host_software, because that table
-- is only indexed on (host_id, software_id).
--
-- Before the first run: a database snapshot, and 2_plan.sql output
-- reviewed.
-- =====================================================================

-- See 2_plan.sql for why these two are set.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

SET @online_hours = 24;
SET @b = (SELECT MIN(batch_no) FROM zz_app_suffix_map WHERE state = 'pending');

-- Undo trail. host_software links can't be rebuilt from Fleet once moved.
-- No unique keys, so a row backed up twice is kept twice rather than
-- dropped. batch_no says which run took the copy.
CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_software AS
  SELECT 0 AS batch_no, s.* FROM software s WHERE 1 = 0;
CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_host_software AS
  SELECT 0 AS batch_no, hs.* FROM host_software hs WHERE 1 = 0;
CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_paths AS
  SELECT 0 AS batch_no, p.* FROM host_software_installed_paths p WHERE 1 = 0;

-- Re-check the batch against the live tables before touching it.
-- Gone: Fleet's own cleanup or ingestion already removed the row.
UPDATE zz_app_suffix_map m
LEFT JOIN software s ON s.id = m.stale_id
SET m.state = 'gone'
WHERE m.batch_no = @b AND m.state = 'pending' AND s.id IS NULL;

-- Online: a host linked to it came back and still reports it.
UPDATE zz_app_suffix_map m
SET m.state = 'skip_online'
WHERE m.batch_no = @b AND m.state = 'pending'
  AND EXISTS (SELECT 1 FROM host_software hs
              JOIN host_seen_times hst ON hst.host_id = hs.host_id
              WHERE hs.software_id = m.stale_id
                AND hst.seen_time >= NOW() - INTERVAL @online_hours HOUR);

-- Rows still in the plan, so none of them becomes another row's survivor.
DROP TEMPORARY TABLE IF EXISTS zz_stale_ids;
CREATE TEMPORARY TABLE zz_stale_ids (id BIGINT UNSIGNED NOT NULL PRIMARY KEY);
INSERT INTO zz_stale_ids SELECT stale_id FROM zz_app_suffix_map WHERE state IN ('pending', 'merged', 'renamed');

-- Pair 'suffix' rows again by checksum, since a host may have reported the
-- twin since 2_plan.sql ran. Rows paired by bundle ID keep that survivor.
-- If the checksum twin is itself a row in the plan, skip: merging would
-- delete both, and renaming would hit the unique checksum key.
UPDATE zz_app_suffix_map m
LEFT JOIN software c ON c.checksum = m.target_checksum
LEFT JOIN zz_stale_ids x ON x.id = c.id
SET m.survivor_id = IF(x.id IS NULL, c.id, NULL),
    m.pair_by = IF(c.id IS NOT NULL AND x.id IS NULL, 'checksum', 'none'),
    m.state = IF(x.id IS NOT NULL, 'skip_stale_twin', m.state)
WHERE m.batch_no = @b AND m.state = 'pending' AND m.kind = 'suffix' AND m.pair_by <> 'bundle';

-- Survivors found by bundle ID or by group must still exist.
UPDATE zz_app_suffix_map m
LEFT JOIN software c ON c.id = m.survivor_id
SET m.state = 'skip_no_survivor'
WHERE m.batch_no = @b AND m.state = 'pending' AND m.pair_by IN ('bundle', 'group') AND c.id IS NULL;

-- A survivor with no host links is an orphan that Fleet's vulnerabilities
-- cron is about to delete. Merging into it would leave links to a deleted
-- row. Skip; once Fleet removes the orphan, a new 2_plan.sql turns the row
-- into a rename.
UPDATE zz_app_suffix_map m
SET m.state = 'skip_orphan_twin'
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM host_software hs WHERE hs.software_id = m.survivor_id);

START TRANSACTION;

INSERT INTO zz_app_suffix_bak_software
SELECT @b, s.* FROM software s
JOIN zz_app_suffix_map m ON m.stale_id = s.id
WHERE m.batch_no = @b AND m.state = 'pending';

INSERT INTO zz_app_suffix_bak_host_software
SELECT @b, hs.* FROM host_software hs
JOIN zz_app_suffix_map m ON m.stale_id = hs.software_id
WHERE m.batch_no = @b AND m.state = 'pending';

INSERT INTO zz_app_suffix_bak_paths
SELECT @b, p.* FROM zz_app_suffix_map m
STRAIGHT_JOIN host_software hs ON hs.software_id = m.stale_id
STRAIGHT_JOIN host_software_installed_paths p FORCE INDEX (host_id_software_id_idx)
  ON p.host_id = hs.host_id AND p.software_id = hs.software_id
WHERE m.batch_no = @b AND m.state = 'pending';

-- ---------------------------------------------------------------------
-- MERGE rows (a twin exists)
--
-- STRAIGHT_JOIN pins the join order to start from the plan's stale rows.
-- Started from the survivor instead, MySQL would scan and lock the links
-- of every host that has the survivor, which Fleet writes to on each
-- software report.
-- ---------------------------------------------------------------------

-- Installed paths first, while the stale host_software links still exist
-- to reach them by index. Drop the paths the twin already has for that
-- host, then move the rest. Otherwise the host shows the path twice.
DELETE p FROM zz_app_suffix_map m
STRAIGHT_JOIN host_software hs ON hs.software_id = m.stale_id
STRAIGHT_JOIN host_software_installed_paths p FORCE INDEX (host_id_software_id_idx)
  ON p.host_id = hs.host_id AND p.software_id = hs.software_id
STRAIGHT_JOIN host_software_installed_paths q FORCE INDEX (host_id_software_id_idx)
  ON q.host_id = hs.host_id AND q.software_id = m.survivor_id AND q.installed_path = p.installed_path
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

UPDATE zz_app_suffix_map m
STRAIGHT_JOIN host_software hs ON hs.software_id = m.stale_id
STRAIGHT_JOIN host_software_installed_paths p FORCE INDEX (host_id_software_id_idx)
  ON p.host_id = hs.host_id AND p.software_id = hs.software_id
SET p.software_id = m.survivor_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

-- A host linked to both rows keeps the twin's link. Carry the newer
-- last_opened_at over first, so "last opened" reports don't go back in
-- time.
UPDATE zz_app_suffix_map m
STRAIGHT_JOIN host_software st ON st.software_id = m.stale_id
STRAIGHT_JOIN host_software surv ON surv.host_id = st.host_id AND surv.software_id = m.survivor_id
SET surv.last_opened_at = st.last_opened_at
WHERE m.batch_no = @b AND m.state = 'pending'
  AND st.last_opened_at IS NOT NULL
  AND (surv.last_opened_at IS NULL OR st.last_opened_at > surv.last_opened_at);

-- Then drop the stale link. (host_id, software_id) is the primary key, so
-- it can't be moved onto a link that already exists.
DELETE st FROM zz_app_suffix_map m
STRAIGHT_JOIN host_software st ON st.software_id = m.stale_id
STRAIGHT_JOIN host_software surv ON surv.host_id = st.host_id AND surv.software_id = m.survivor_id
WHERE m.batch_no = @b AND m.state = 'pending';

-- Move the remaining links.
UPDATE zz_app_suffix_map m
STRAIGHT_JOIN host_software hs ON hs.software_id = m.stale_id
SET hs.software_id = m.survivor_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

-- software_cve, software_host_counts and kernel_host_counts have no
-- foreign key to software, so they're cleared by hand, as Fleet's merge
-- does. software_cpe cascades on delete, and so does software_metadata on
-- Fleet versions that have it.
DELETE cve FROM software_cve cve
JOIN zz_app_suffix_map m ON m.stale_id = cve.software_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

DELETE shc FROM software_host_counts shc
JOIN zz_app_suffix_map m ON m.stale_id = shc.software_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

DELETE khc FROM kernel_host_counts khc
JOIN zz_app_suffix_map m ON m.stale_id = khc.software_id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

DELETE s FROM software s
JOIN zz_app_suffix_map m ON m.stale_id = s.id
WHERE m.batch_no = @b AND m.state = 'pending' AND m.survivor_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- RENAME rows (kind 'suffix', no twin)
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
WHERE m.batch_no = @b AND m.state = 'pending' AND m.kind = 'suffix' AND m.survivor_id IS NULL;

-- Record what actually happened, not what was intended. Anything else is
-- 'failed', and 5_verify.sql lists it.
UPDATE zz_app_suffix_map m
LEFT JOIN software s ON s.id = m.stale_id
SET m.state = CASE
    WHEN m.survivor_id IS NOT NULL AND s.id IS NULL THEN 'merged'
    WHEN m.survivor_id IS NULL AND s.checksum = m.target_checksum AND s.name = m.trimmed_name THEN 'renamed'
    ELSE 'failed' END
WHERE m.batch_no = @b AND m.state = 'pending';

COMMIT;

SELECT @b AS batch_applied, state, COUNT(*) AS software_rows
FROM zz_app_suffix_map
GROUP BY state
UNION ALL
SELECT @b, 'pending (total)', COUNT(*) FROM zz_app_suffix_map WHERE state = 'pending';
