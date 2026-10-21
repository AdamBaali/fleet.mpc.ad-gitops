# C-1: Control install lid open on power

- **Started:** 2026-10-20T10:45:41Z
- **Objective:** A policy automation installs a large app while the laptop is awake on power
- **Expected:** Install succeeds

## Steps and evidence
- `01-activities.txt`: `fleetctl api /api/v1/fleet/hosts/20/activities 2>/dev/null | python3 -c 'import json,sys
for a in reversed(json.load(sys.stdin)["activities"]):
  d=a.get("details") or {}; print(a["created_at"], a["type"], d.get("software_title") or d.get("script_name") `
- `02-install-result-0c293bb9.txt`: `fleetctl api /api/v1/fleet/software/install/0c293bb9-6ccc-4408-b02f-b598d723dfbb/results 2>/dev/null | python3`
- `03-install-result-9692bff7.txt`: `fleetctl api /api/v1/fleet/software/install/9692bff7-f717-4800-8ea9-b3104eb74425/results 2>/dev/null | python3`
- `04-orbit-and-pmset-window.txt`: `python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print("exit", r.get("exit_code")); print(r.get("o`
- `05-orbit-restart-during-download.txt`: `python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print("exit", r.get("exit_code")); print(r.get("o`

Logs read on the laptop through a Fleet script (root), since orbit.stderr.log is root-only. Lid open the whole time on AC (the tester, and AppleClamshellState = No at 13:03 local).

- Chrome: queued 10:31:21Z at enrollment (policy failed on the first check). Download started 12:32:10 local, orbit restarted 12:34:23 (SIGTERM, about 90 s after MDM enrollment at 12:32:55, then read its config from the profile), Fleet re-notified, download restarted 12:35:05, done 12:40:01, install exit 0 at 12:40:09.
- swiftDialog: download 12:41:10 to 12:41:25, install exit 0 at 12:41:28.
- Idle sleep at 12:43:15 local on AC, about 2 minutes after the last install. No sleep during either download.
- Side finding: an orbit restart mid-download drops the download with no error line. Fleet re-sends the install, so it still finished.

## Result: PASS

Chrome and swiftDialog installed by policy automation on AC, lid open. Chrome took 8 min including one restart caused by MDM enrollment

_Finished 2026-10-20T11:04:54Z_
