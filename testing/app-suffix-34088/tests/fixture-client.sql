-- Small fixture for run-client-smoke.sh. Checksums use the same formula as
-- the scripts; the Go test checks that formula against Fleet's own code.
INSERT INTO software (id, name, version, source, bundle_identifier, checksum) VALUES
 (1, 'Zoom.app',  '6.0', 'apps', 'us.zoom.xos', UNHEX(MD5(CONCAT_WS(CHAR(0), '6.0', 'apps', 'us.zoom.xos', '', '', '', '', '', 'Zoom.app')))),
 (2, 'Zoom',      '6.0', 'apps', 'us.zoom.xos', UNHEX(MD5(CONCAT_WS(CHAR(0), '6.0', 'apps', 'us.zoom.xos', '', '', '', '', '', 'Zoom')))),
 (3, 'Notion.app','3.0', 'apps', 'notion.id',   UNHEX(MD5(CONCAT_WS(CHAR(0), '3.0', 'apps', 'notion.id', '', '', '', '', '', 'Notion.app'))));
INSERT INTO host_seen_times (host_id, seen_time) VALUES (1, NOW() - INTERVAL 60 DAY), (2, NOW());
INSERT INTO host_software (host_id, software_id) VALUES (1, 1), (1, 3), (2, 2);
INSERT INTO host_software_installed_paths (host_id, software_id, installed_path) VALUES (1, 1, '/Applications/zoom.us.app');
INSERT INTO software_titles (name, source, bundle_identifier) VALUES ('Zoom.app', 'apps', 'us.zoom.xos');
INSERT INTO fleet_maintained_apps (name, slug, platform, unique_identifier) VALUES ('Zoom', 'zoom/darwin', 'darwin', 'us.zoom.xos');
