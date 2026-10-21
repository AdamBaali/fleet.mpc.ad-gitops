-- =====================================================================
-- 5_verify.sql: check the result
--
-- READ ONLY. Run after the last 3_apply_batch.sql run, then again a day
-- later once hosts have reported.
--
-- Host counts on the Software page come from software_host_counts, which
-- Fleet rebuilds in the vulnerabilities cron. Run it, or wait for it:
--   fleetctl trigger --name vulnerabilities
-- If vulnerability processing runs as a separate `fleet vuln_processing`
-- job, run that job instead.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 1. Plan outcome. Expected: no 'pending' and no 'failed'. 'skip_*' rows
-- were left alone on purpose: see 3_apply_batch.sql for each reason.
SELECT state, COUNT(*) AS software_rows FROM zz_app_suffix_map GROUP BY state;

-- 2. Every renamed row carries the checksum the plan computed for its new
-- name. Expected: 0. (Compared with the plan rather than recomputed from
-- the current name, because the Fleet-maintained app job may rename the
-- row again later and keep the checksum.)
SELECT COUNT(*) AS renamed_with_wrong_checksum
FROM zz_app_suffix_map m
JOIN software s ON s.id = m.stale_id
WHERE m.state = 'renamed' AND s.checksum <> m.target_checksum;

-- 3. No host link or installed path of the touched hosts points at a
-- deleted software row. Expected: 0 and 0.
SELECT
  (SELECT COUNT(*) FROM host_software hs
     LEFT JOIN software s ON s.id = hs.software_id
    WHERE hs.host_id IN (SELECT DISTINCT host_id FROM zz_app_suffix_bak_host_software)
      AND s.id IS NULL) AS links_to_missing_software,
  (SELECT COUNT(*) FROM host_software_installed_paths p
     LEFT JOIN software s ON s.id = p.software_id
    WHERE p.host_id IN (SELECT DISTINCT host_id FROM zz_app_suffix_bak_host_software)
      AND s.id IS NULL) AS paths_to_missing_software;

-- 4. Copies left next to the rows the plan merged into: same name,
-- version and identity as a survivor, not skipped on purpose. Expected: 0,
-- unless online hosts still use another copy (old checksums from
-- fleetdm/fleet#52314, or a copy the Fleet-maintained app job renamed).
-- 1_diagnose.sql CHECK 7 and CHECK 9 count those.
SELECT COUNT(*) AS duplicates_in_touched_groups FROM (
  SELECT 1
  FROM software s
  JOIN software v ON v.id IN (SELECT survivor_id FROM zz_app_suffix_map WHERE state = 'merged')
                 AND v.name = s.name AND v.version = s.version AND v.source = s.source
                 AND COALESCE(v.bundle_identifier, '') = COALESCE(s.bundle_identifier, '')
                 AND v.`release` = s.`release` AND v.arch = s.arch AND v.vendor = s.vendor
                 AND v.extension_for = s.extension_for AND v.extension_id = s.extension_id
  WHERE s.id <> v.id
    AND s.id NOT IN (SELECT stale_id FROM zz_app_suffix_map WHERE state LIKE 'skip%')
) d;

-- 5. What still ends in ".app". Re-run 1_diagnose.sql for the full
-- picture. Expected after the cleanup: rows for excluded bundle IDs
-- (Firefox), and rows on hosts that came online or went offline after the
-- plan.
SELECT COALESCE(s.bundle_identifier, '') AS bundle_identifier, COUNT(*) AS software_rows
FROM software s
WHERE s.source = 'apps' AND s.name LIKE '%.app' AND CHAR_LENGTH(s.name) > 4
GROUP BY bundle_identifier
ORDER BY software_rows DESC
LIMIT 25;

-- Once the result is settled, keep the zz_ tables for a week, then:
--   DROP TABLE zz_app_suffix_map, zz_app_suffix_bak_software,
--     zz_app_suffix_bak_host_software, zz_app_suffix_bak_paths, zz_app_suffix_bak_titles;
