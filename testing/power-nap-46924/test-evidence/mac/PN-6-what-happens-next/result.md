# PN-6: What happens next

- **Started:** 2026-10-20T13:03:44Z
- **Objective:** After PN-1, open the lid and see if and when the automation retries
- **Expected:** Unknown

## Steps and evidence
- `01-fleet-retry-watch.txt`: `cat fleet-retry-watch.txt`
- `02-activities.txt`: `fleetctl api /api/v1/fleet/hosts/20/activities 2>/dev/null | python3 -c 'import json,sys
for a in reversed(json.load(sys.stdin)["activities"]):
  d=a.get("details") or {}; print(a["created_at"], a["type"], d.get("software_title") or "-", d.get("status"))`

Fleet re-queued the install at the failure (12:23:26Z). It was not delivered in the two DarkWakes that followed with the lid closed. After the lid opened at 13:00:34Z, fleetd got the retry at 13:01:24Z (50 s), downloaded in 28 s and installed at 13:01:57Z. The policy passed at 13:02:17Z. Same orbit log as PN-1 (02-orbit-installer.txt there).

## Result: PASS

Fleet retried once after the failure. The retry waited for the lid to open and installed 83 s after the wake

_Finished 2026-10-20T13:03:45Z_
