# fleetd health check scripts (https://github.com/fleetdm/fleet/pull/59727)

Tests the fixed Windows health check script from the pull request on a healthy lab host, against the published version as
a negative control. Support sends this script to customers to collect fleetd logs, so false failures cost a round trip.

**Status:** 2026-11-24, scripts added to the Device IDs Lab fleet through GitOps. T-1 done; runs wait for a token that
can run scripts.

## What we found
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
