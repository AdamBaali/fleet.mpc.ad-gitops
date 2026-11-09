# T-1: Query logic on faked data

- **Started:** 2026-11-09T15:18:28Z
- **Objective:** Both queries return the faked IDs
- **Expected:** Intune row equals expected intune_device_id; Entra row equals expected entra_device_id

## Steps and evidence
- `01-fake-setup.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 setup'`
- `02-intune.txt`: `scripts/vm-query.sh ids1 queries/intune-device-id.sql`
- `03-entra.txt`: `scripts/vm-query.sh ids1 queries/entra-device-id.sql`
- `04-certs.txt`: `scripts/vm-query.sh ids1 queries/checks/personal-certs.sql`

osquery renders the leaf's subject and common_name as the bare GUID, and the issuer as 'net + windows + MS-Organization-Access + 82dbaca4-...', which Fleet's LIKE matches.

## Result: PASS

Intune row equals expected intune_device_id with its enrollment key. Entra row equals expected entra_device_id; common_name and subject both hold the bare GUID.

_Finished 2026-11-09T15:21:12Z_
