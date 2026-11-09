# T-2b: JoinInfo without its certificate

- **Started:** 2026-11-09T15:19:22Z
- **Objective:** A subkey whose certificate is gone is ignored
- **Expected:** Intune row only; no Entra row

## Steps and evidence
- `01-fake-nocert.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 nocert'`
- `02-intune.txt`: `scripts/vm-query.sh ids1 queries/intune-device-id.sql`
- `03-entra.txt`: `scripts/vm-query.sh ids1 queries/entra-device-id.sql`

## Result: PASS

JoinInfo subkey with no matching certificate: Intune row only, no Entra row.

_Finished 2026-11-09T15:21:12Z_
