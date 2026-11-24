# fleetd health check scripts (https://github.com/fleetdm/fleet/pull/59727)

Tests the fixed Windows health check script from the pull request on a healthy lab host, against the published version as
a negative control. Support sends this script to customers to collect fleetd logs, so false failures cost a round trip.

**Status:** 2026-11-24, all tests pass on host 37. Teardown pending in HANDOFF.md.

## What we found
- T-3 and T-4: on the same healthy host, the published script fails (`[FAIL]` enroll secret, exit 1) and the
  pull request version passes (exit 0).
- T-4: the MDM section listed built-in Windows entries. Fixed in the pull request and confirmed in T-4b.
- T-5: archives are created in `C:\Windows\Temp` with `summary.txt` and the new MDM logs.
- T-1: host 37 is healthy and enrolled with no `secret.txt` and no `HKLM\SOFTWARE\FleetDM\Orbit` key. The published
  script reports both as problems on such a host.

## Files
| File | What |
|---|---|
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [RESULTS.md](RESULTS.md) | One entry per test |
| [NOTES.md](NOTES.md) | Lab versus production, what was not tested, sources |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| [tools/run-script.sh](tools/run-script.sh) | Runs a saved script on a host through the API and prints the result |
| `../../lib/windows/scripts/fleetd-healthcheck.ps1` | Pull request version |
| `../../lib/windows/scripts/fleetd-healthcheck-main.ps1` | Published version (negative control) |
