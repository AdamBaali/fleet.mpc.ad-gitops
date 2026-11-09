# T-2c: Certificate from another issuer

- **Started:** 2026-11-09T15:19:46Z
- **Objective:** A matching subkey and certificate from a non-Entra issuer is ignored
- **Expected:** No Entra row

## Steps and evidence
- `01-fake-otherca.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 otherca'`
- `02-intune.txt`: `scripts/vm-query.sh ids1 queries/intune-device-id.sql`
- `03-entra.txt`: `scripts/vm-query.sh ids1 queries/entra-device-id.sql`

## Result: PASS

Matching subkey and certificate from a non-Entra issuer: no Entra row.

_Finished 2026-11-09T15:21:12Z_
