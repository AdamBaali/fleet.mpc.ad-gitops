SELECT
  (SELECT group_concat(username) FROM users WHERE type = 'local') AS local_users,
  (SELECT count(*) FROM file WHERE path IN ('C:\lab-marker.txt', 'C:\Users\lab1-data\marker.txt')) AS markers_left,
  (SELECT group_concat(status) FROM services WHERE name LIKE 'Fleet osquery%') AS fleetd_service,
  (SELECT group_concat(filename) FROM file WHERE directory = 'C:\ProgramData\Microsoft\Provisioning\' AND filename LIKE '%.ppkg') AS kept_ppkg,
  (SELECT group_concat(filename) FROM file WHERE directory = 'C:\Recovery\Customizations\') AS staged_ppkg,
  (SELECT total_seconds FROM uptime) AS uptime_s;
