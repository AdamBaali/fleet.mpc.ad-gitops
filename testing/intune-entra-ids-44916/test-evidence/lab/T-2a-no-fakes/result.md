# T-2a: No fakes

- **Started:** 2026-11-09T15:18:58Z
- **Objective:** Queries return nothing on a host that is not joined or enrolled
- **Expected:** No rows from either query

## Steps and evidence
- `01-fake-clear.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 clear'`
- `02-intune.txt`: `scripts/vm-query.sh ids1 queries/intune-device-id.sql`
- `03-entra.txt`: `scripts/vm-query.sh ids1 queries/entra-device-id.sql`

## Result: PASS

Both queries return no rows with no fakes, next to 31 built-in Enrollments subkeys.

_Finished 2026-11-09T15:21:12Z_
