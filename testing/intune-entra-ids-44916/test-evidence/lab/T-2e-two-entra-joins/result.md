# T-2e: Two Entra joins

- **Started:** 2026-11-09T15:20:31Z
- **Objective:** The newest join certificate wins
- **Expected:** One Entra row with the newer certificate's ID

## Steps and evidence
- `01-fake-twojoins.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 twojoins'`
- `02-intune.txt`: `scripts/vm-query.sh ids1 queries/intune-device-id.sql`
- `03-entra.txt`: `scripts/vm-query.sh ids1 queries/entra-device-id.sql`
- `04-fake-clear.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 clear'`

## Result: PASS

Two Entra joins with matching certificates: one row, the newer certificate's ID.

_Finished 2026-11-09T15:21:12Z_
