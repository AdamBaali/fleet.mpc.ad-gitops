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

-- 1. Plan outcome. Expected: no 'pending'.
SELECT state, COUNT(*) AS software_rows FROM zz_app_suffix_map GROUP BY state;

-- 2. Every renamed row's checksum matches its new name. Expected: 0.
SELECT COUNT(*) AS renamed_with_wrong_checksum
FROM zz_app_suffix_map m
JOIN software s ON s.id = m.stale_id
WHERE m.state = 'renamed'
  AND s.checksum <> UNHEX(MD5(CONCAT_WS(CHAR(0),
        s.version, s.source, COALESCE(s.bundle_identifier, ''), s.`release`,
        s.arch, s.vendor, s.extension_for, s.extension_id, s.name,
        NULLIF(s.application_id, ''), NULLIF(s.upgrade_code, ''))));

-- 3. No host link points at a deleted software row. Expected: 0.
SELECT COUNT(*) AS links_to_missing_software
FROM host_software hs
JOIN zz_app_suffix_bak_host_software b ON b.host_id = hs.host_id
LEFT JOIN software s ON s.id = hs.software_id
WHERE s.id IS NULL;

-- 4. No duplicate versions: two rows with the same identity. Expected: 0.
SELECT COUNT(*) AS duplicate_identity_groups FROM (
  SELECT 1 FROM software
  WHERE source = 'apps'
  GROUP BY name, version, COALESCE(bundle_identifier, ''), `release`, arch, vendor,
           extension_for, extension_id
  HAVING COUNT(*) > 1
) d;

-- 5. What still ends in ".app", by bucket. Re-run 1_diagnose.sql CHECK 2
-- for the full picture. Expected after the cleanup: only 'recurring' rows
-- for excluded bundle IDs, and offline rows for hosts that went offline
-- after the plan.
SELECT COALESCE(s.bundle_identifier, '') AS bundle_identifier, COUNT(*) AS software_rows
FROM software s
WHERE s.source = 'apps' AND s.name LIKE '%.app' AND CHAR_LENGTH(s.name) > 4
GROUP BY bundle_identifier
ORDER BY software_rows DESC
LIMIT 25;

-- Once the result is settled, keep the zz_ tables for a week, then:
--   DROP TABLE zz_app_suffix_map, zz_app_suffix_bak_software,
--     zz_app_suffix_bak_host_software, zz_app_suffix_bak_paths, zz_app_suffix_bak_titles;
