-- Entra device ID. Candidate, not tested: see ../TEST_PLAN.md.
-- There is no DeviceId registry value. The JoinInfo subkey is named after the device
-- certificate's thumbprint, and that certificate's subject is the device ID. Matching the two
-- mirrors Fleet's windowsEntraJoinUser query (fleet-v4.93.1), which ignores stale subkeys and
-- user-store certificates from Entra registered devices. Newest certificate wins.
-- Both subject and common_name are returned until a real host shows which is the bare GUID.
SELECT c.common_name AS entra_device_id,
       c.subject AS cert_subject,
       c.not_valid_after AS cert_not_valid_after
FROM registry r
CROSS JOIN certificates c
  ON UPPER(c.sha1) = UPPER(SUBSTR(r.key, LENGTH('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\') + 1))
WHERE r.key LIKE 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\%'
  AND c.issuer LIKE 'net + windows + MS-Organization-Access%'
GROUP BY r.key
ORDER BY MAX(c.not_valid_after) DESC
LIMIT 1;
