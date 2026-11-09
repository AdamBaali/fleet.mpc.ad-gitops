-- Intune device ID (EntDMID). Candidate, not tested: see ../TEST_PLAN.md.
-- Same source as the customer's report. It returns every match with its key, not LIMIT 1,
-- because stale enrollment keys can survive a re-image and would otherwise hide.
SELECT data AS intune_device_id,
       key AS enrollment_key
FROM registry
WHERE path LIKE 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Enrollments\%\DMClient\MS DM Server\%'
  AND name = 'EntDMID';
