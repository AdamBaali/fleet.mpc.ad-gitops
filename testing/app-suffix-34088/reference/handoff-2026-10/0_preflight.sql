-- =====================================================================
-- 0_preflight.sql
-- .app suffix cleanup - preflight checks
--
-- READ ONLY. Run this first. It answers one question: is it safe and
-- worthwhile to run the cleanup yet, or would it just come back?
--
-- Run against the primary, not a replica.
-- =====================================================================

-- ---------------------------------------------------------------------
-- CHECK 1: Fleet version
--
-- The ingestion fix must already be live, otherwise hosts keep writing
-- new ".app" rows and the cleanup recurs within the hour.
--
-- Confirm in the UI (My account > version) or:
--   GET /api/v1/fleet/version
--
-- Required: 4.82.0 or later.
--   - the trim itself was corrected earlier (fleetdm/fleet#34620)
--   - 4.82.0 fixed the follow-on regression where the corrected trim
--     could produce empty names (fleetdm/fleet#39563)
--
-- If the instance is below 4.82.0: STOP. Upgrade first.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- CHECK 2: Is the bug actually still active?
--
-- This is the check the original script did not have.
--
-- Fleet deletes host_software links for software a host no longer
-- reports. So if a host reported recently AND is still linked to a
-- ".app" row, the host is still being ingested with the suffix, which
-- means the ingestion fix is NOT in effect on this instance.
--
-- Expected result if safe to proceed: 0 rows.
-- Any rows here mean the cleanup will recur. Investigate before running.
-- ---------------------------------------------------------------------
SELECT
  s.id                        AS software_id,
  s.name,
  s.version,
  s.bundle_identifier,
  COUNT(DISTINCT hs.host_id)  AS hosts_still_reporting,
  MAX(hu.software_updated_at) AS most_recent_report
FROM software s
JOIN host_software hs ON hs.software_id = s.id
JOIN host_updates  hu ON hu.host_id     = hs.host_id
WHERE s.source = 'apps'
  AND s.name LIKE '%.app'
  AND CHAR_LENGTH(s.name) > 4
  AND hu.software_updated_at > NOW() - INTERVAL 24 HOUR
GROUP BY s.id, s.name, s.version, s.bundle_identifier
ORDER BY hosts_still_reporting DESC
LIMIT 50;

-- ---------------------------------------------------------------------
-- CHECK 3: Scope and blast radius
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                                   AS stale_software_rows,
  COUNT(DISTINCT s.bundle_identifier)        AS distinct_bundle_ids,
  (SELECT COUNT(*)
     FROM host_software hs
     JOIN software s2 ON s2.id = hs.software_id
    WHERE s2.source = 'apps'
      AND s2.name LIKE '%.app'
      AND CHAR_LENGTH(s2.name) > 4)          AS host_software_links_affected,
  (SELECT COUNT(*)
     FROM software_titles t
    WHERE t.source = 'apps'
      AND t.name LIKE '%.app'
      AND CHAR_LENGTH(t.name) > 4)           AS stale_titles
FROM software s
WHERE s.source = 'apps'
  AND s.name LIKE '%.app'
  AND CHAR_LENGTH(s.name) > 4;

-- ---------------------------------------------------------------------
-- CHECK 4: Checksum integrity
--
-- The merge assumes at most one canonical row exists per identity,
-- which the UNIQUE index on software.checksum guarantees only while
-- stored checksums match the identity columns. If checksums have
-- drifted, duplicate identity groups exist and pairing is ambiguous.
--
-- Expected: 0 rows. If not, let Fleet's own reconciliation run first
-- (shipped in 4.90.0) rather than merging by hand.
-- ---------------------------------------------------------------------
SELECT
  name, version, source, COALESCE(bundle_identifier, '') AS bundle_identifier,
  COUNT(*) AS member_count
FROM software
WHERE source = 'apps'
GROUP BY
  name, version, source, COALESCE(bundle_identifier, ''), `release`,
  arch, vendor, extension_for, extension_id,
  COALESCE(application_id, ''), COALESCE(upgrade_code, '')
HAVING COUNT(*) > 1
LIMIT 25;

-- ---------------------------------------------------------------------
-- CHECK 5: Replication and free space
--
-- The merge rewrites host_software, which is the largest table on most
-- instances. Confirm replica lag is healthy and there is headroom
-- before starting.
-- ---------------------------------------------------------------------
SELECT
  table_name,
  table_rows,
  ROUND((data_length + index_length) / 1024 / 1024 / 1024, 2) AS size_gb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'software', 'host_software', 'host_software_installed_paths',
    'software_cve', 'software_host_counts', 'software_titles'
  )
ORDER BY (data_length + index_length) DESC;
