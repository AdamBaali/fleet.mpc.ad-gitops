# T-2d: Stale second enrollment

- **Started:** 2026-11-09T15:20:08Z
- **Objective:** An older Intune enrollment key is visible, not hidden
- **Expected:** Two Intune rows, each with its key; one Entra row

## Steps and evidence
- `01-fake-stale.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 stale'`
- `02-intune.txt`: `scripts/vm-query.sh ids1 queries/intune-device-id.sql`
- `03-entra.txt`: `scripts/vm-query.sh ids1 queries/entra-device-id.sql`

## Result: PASS

Two Intune rows, each with its enrollment key, so a stale enrollment is visible. One Entra row.

_Finished 2026-11-09T15:21:12Z_
