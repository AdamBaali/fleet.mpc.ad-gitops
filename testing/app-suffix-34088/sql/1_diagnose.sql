-- =====================================================================
-- 1_diagnose.sql: macOS software names that end in ".app"
--
-- READ ONLY. Creates nothing and changes nothing. Safe on a replica.
-- Tested on Fleet 4.93 schema (see ../TEST_PLAN.md, D-3).
--
-- Answers three questions before anyone changes data:
--   1. Is something still producing ".app" names? (CHECK 1 and 2)
--   2. Of the rows that exist, which heal on their own and which do not?
--   3. Can the cleanup's checksum formula be trusted on this database? (CHECK 4)
--
-- Share the output of every CHECK. Names and bundle IDs only, no host data.
-- =====================================================================

-- A host counts as "online" if Fleet saw it within this many hours.
SET @online_hours = 24;

-- ---------------------------------------------------------------------
-- CHECK 1: detail query overrides and software inventory settings
--
-- A software_macos override that selects apps.name keeps ".app" in every
-- name it sends. Fleet's own macos_firefox override does the same for
-- Firefox on any host with the parse_ini table (fleetd, or osquery with a
-- fleetd tables extension). Teams with software inventory turned off never
-- update their hosts' software, so their old links never move.
--
-- Expected: no software_macos override anywhere. Note any team where
-- enable_software_inventory is false.
-- ---------------------------------------------------------------------
SELECT 'global' AS scope,
       0 AS team_id,
       JSON_KEYS(JSON_EXTRACT(json_value, '$.features.detail_query_overrides')) AS overridden_queries,
       JSON_EXTRACT(json_value, '$.features.enable_software_inventory') AS software_inventory
FROM app_config_json
UNION ALL
SELECT 'team', t.id,
       JSON_KEYS(JSON_EXTRACT(t.config, '$.features.detail_query_overrides')),
       JSON_EXTRACT(t.config, '$.features.enable_software_inventory')
FROM teams t
WHERE JSON_EXTRACT(t.config, '$.features.detail_query_overrides') IS NOT NULL
   OR JSON_EXTRACT(t.config, '$.features.enable_software_inventory') = false;

-- ---------------------------------------------------------------------
-- CHECK 2: where the ".app" rows are, by bucket
--
-- Fleet replaces a host's whole software list on each report, keyed by
-- name. A host that reports "Slack" loses its link to "Slack.app" in that
-- same report. So a ".app" row still linked to an ONLINE host means that
-- host still sends the ".app" name today.
--
--   recurring      linked to at least one online host. Something still
--                  produces this name. A cleanup will not last.
--   offline_only   linked only to hosts not seen recently. Heals by itself
--                  when those hosts report. Only these are cleanup targets.
--   orphaned       no host links. Fleet's vulnerabilities cron deletes
--                  these (SyncHostsSoftware). Nothing to do.
-- ---------------------------------------------------------------------
SELECT bucket,
       (bundle_identifier = 'org.mozilla.firefox') AS is_firefox,
       COUNT(*)            AS software_rows,
       SUM(online_hosts)   AS links_online_hosts,
       SUM(offline_hosts)  AS links_offline_hosts
FROM (
  SELECT s.id, s.bundle_identifier,
         COALESCE(l.online_hosts, 0)  AS online_hosts,
         COALESCE(l.offline_hosts, 0) AS offline_hosts,
         CASE WHEN l.software_id IS NULL THEN 'orphaned'
              WHEN l.online_hosts > 0    THEN 'recurring'
              ELSE 'offline_only' END    AS bucket
  FROM software s
  LEFT JOIN (
    SELECT hs.software_id,
           SUM(hst.seen_time >= NOW() - INTERVAL @online_hours HOUR)            AS online_hosts,
           SUM(COALESCE(hst.seen_time < NOW() - INTERVAL @online_hours HOUR, 1)) AS offline_hosts
    FROM host_software hs
    JOIN software s2 ON s2.id = hs.software_id
    LEFT JOIN host_seen_times hst ON hst.host_id = hs.host_id
    WHERE s2.source = 'apps' AND s2.name LIKE '%.app' AND CHAR_LENGTH(s2.name) > 4
    GROUP BY hs.software_id
  ) l ON l.software_id = s.id
  WHERE s.source = 'apps' AND s.name LIKE '%.app' AND CHAR_LENGTH(s.name) > 4
) x
GROUP BY bucket, is_firefox
ORDER BY bucket, is_firefox;

-- ---------------------------------------------------------------------
-- CHECK 3: recurring names, most hosts first
--
-- Every name here is still being sent by online hosts. Firefox and
-- Firefox ESR come from Fleet's macos_firefox query. Anything else points
-- at a detail query override (CHECK 1) or an app whose own bundle name
-- ends in ".app".
-- ---------------------------------------------------------------------
SELECT s.name, s.bundle_identifier,
       COUNT(DISTINCT s.id)       AS versions,
       COUNT(DISTINCT hs.host_id) AS online_hosts
FROM software s
JOIN host_software hs ON hs.software_id = s.id
JOIN host_seen_times hst ON hst.host_id = hs.host_id
WHERE s.source = 'apps' AND s.name LIKE '%.app' AND CHAR_LENGTH(s.name) > 4
  AND hst.seen_time >= NOW() - INTERVAL @online_hours HOUR
GROUP BY s.name, s.bundle_identifier
ORDER BY online_hosts DESC
LIMIT 50;

-- ---------------------------------------------------------------------
-- CHECK 4: checksum formula integrity
--
-- The cleanup finds the correctly named row the way Fleet's ingestion
-- does: by checksum. It computes checksums in SQL, so the formula must
-- give the stored value for existing rows. The formula is the one Fleet's
-- own migration 20260810160000_DedupeSoftwareChecksums uses, which
-- mirrors Software.ComputeRawChecksum (server/fleet/software.go).
--
--   current         matches today's formula. The cleanup works on these.
--   legacy_pre_4_75 matches the formula from before 4.75.0, which left
--                   the name out for macOS apps. The 4.75.0 migration
--                   recomputed apps with a bundle ID, so expect these only
--                   for apps without one. They can duplicate
--                   (fleetdm/fleet#52314). The cleanup skips them.
--   unexplained     matches neither. Expected: 0. If not, STOP and send
--                   these numbers.
-- ---------------------------------------------------------------------
SELECT
  SUM(cur)                     AS current,
  SUM(NOT cur AND legacy)      AS legacy_pre_4_75,
  SUM(NOT cur AND NOT legacy)  AS unexplained
FROM (
  SELECT
    s.checksum = UNHEX(MD5(CONCAT_WS(CHAR(0),
        s.version, s.source, COALESCE(s.bundle_identifier, ''), s.`release`,
        s.arch, s.vendor, s.extension_for, s.extension_id, s.name,
        NULLIF(s.application_id, ''), NULLIF(s.upgrade_code, '')))) AS cur,
    s.checksum = UNHEX(MD5(CONCAT_WS(CHAR(0),
        s.version, s.source, COALESCE(s.bundle_identifier, ''), s.`release`,
        s.arch, s.vendor, s.extension_for, s.extension_id))) AS legacy
  FROM software s
  WHERE s.source = 'apps'
) c;

-- ---------------------------------------------------------------------
-- CHECK 5: does a correctly named twin exist for each ".app" row?
--
-- paired:   a row with the same identity minus ".app" exists. Cleanup
--           merges the hosts onto it.
-- unpaired: no twin yet. Cleanup renames the row and recomputes its
--           checksum, as Fleet's own 4.75.0 migration did.
-- ---------------------------------------------------------------------
SELECT (c.id IS NOT NULL) AS paired, COUNT(*) AS software_rows
FROM software s
LEFT JOIN software c
  ON c.checksum = UNHEX(MD5(CONCAT_WS(CHAR(0),
       s.version, s.source, COALESCE(s.bundle_identifier, ''), s.`release`,
       s.arch, s.vendor, s.extension_for, s.extension_id,
       LEFT(s.name, CHAR_LENGTH(s.name) - 4),
       NULLIF(s.application_id, ''), NULLIF(s.upgrade_code, ''))))
WHERE s.source = 'apps' AND s.name LIKE '%.app' AND CHAR_LENGTH(s.name) > 4
GROUP BY paired;

-- ---------------------------------------------------------------------
-- CHECK 6: titles and admin display names
--
-- Titles are shared by every version and are never renamed by ingestion,
-- so a ".app" title stays until someone renames it. Display names are set
-- by admins on purpose and are reported only, never changed by these
-- scripts.
-- ---------------------------------------------------------------------
SELECT 'title' AS kind, t.id, t.name, t.bundle_identifier
FROM software_titles t
WHERE t.source = 'apps' AND t.name LIKE '%.app' AND CHAR_LENGTH(t.name) > 4
UNION ALL
SELECT 'display_name', d.software_title_id, d.display_name, NULL
FROM software_title_display_names d
WHERE d.display_name LIKE '%.app' AND CHAR_LENGTH(d.display_name) > 4
ORDER BY kind, name
LIMIT 200;

-- ---------------------------------------------------------------------
-- CHECK 7: duplicate versions across all software (fleetdm/fleet#52314)
--
-- Not about ".app". Rows created before 4.75.0 kept an old checksum, so a
-- host reporting the same software again can create a second row: same
-- name, version and source, split host counts. Fleet repaired giflib only
-- (4.91.0). This counts what is left, by source, so the issue can be sized.
-- Same grouping as the query in #52314. Scans `software`: about 3 to 4
-- seconds per million rows.
-- ---------------------------------------------------------------------
SELECT source,
       COUNT(*)      AS duplicate_groups,
       SUM(dup_rows) AS rows_in_groups
FROM (
  SELECT ANY_VALUE(source) AS source, COUNT(*) AS dup_rows
  FROM software
  GROUP BY UNHEX(MD5(CONCAT_WS(CHAR(0),
      version, source, COALESCE(bundle_identifier, ''), `release`, arch, vendor,
      extension_for, extension_id, name,
      NULLIF(COALESCE(application_id, ''), ''), NULLIF(COALESCE(upgrade_code, ''), ''))))
  HAVING COUNT(*) > 1
) d
GROUP BY source
ORDER BY rows_in_groups DESC;

-- ---------------------------------------------------------------------
-- CHECK 8: table sizes, for planning a window
-- ---------------------------------------------------------------------
SELECT table_name, table_rows,
       ROUND((data_length + index_length) / POW(1024, 3), 2) AS size_gb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('software', 'host_software', 'host_software_installed_paths',
                     'software_cve', 'software_host_counts', 'software_titles')
ORDER BY (data_length + index_length) DESC;
