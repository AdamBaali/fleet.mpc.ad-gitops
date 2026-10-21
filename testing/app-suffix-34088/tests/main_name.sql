SELECT COALESCE(NULLIF(display_name, ''), NULLIF(bundle_name, ''), NULLIF(NULLIF(bundle_executable, ''), 'run.sh'),
  CASE WHEN name IS NOT NULL AND lower(name) LIKE '%.app' THEN substr(name, 1, length(name) - 4) ELSE name END) AS name,
  name AS apps_table_name, bundle_identifier, COALESCE(NULLIF(bundle_short_version, ''), bundle_version) AS version
FROM apps WHERE bundle_identifier = 'org.mozilla.firefox';
