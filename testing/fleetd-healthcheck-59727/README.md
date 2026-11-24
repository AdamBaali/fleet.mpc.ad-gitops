# fleetd health check scripts (https://github.com/fleetdm/fleet/pull/59727)

Tests the fixed health check scripts from the pull request on Windows, Linux and macOS lab hosts, run through Fleet, with
the published versions as negative controls. Support sends this script to customers to collect fleetd logs, so false failures cost a round trip.

**Status:** 2026-11-24, Windows (host 37), Linux (host 38) and macOS (host 12) all pass with the final scripts.
Teardown pending in HANDOFF.md.

## What we found
- Running on real hosts found five more bugs in the pull request, all fixed: a false Linux enroll secret FAIL (L-1),
  macOS log searches too slow for Fleet's 5-minute limit (M-1), orbit missed when Fleet runs the script and when orbit
  has auto-updated (M-2, M-3), and macOS `pgrep -lf` exposing the enroll secret from osqueryd's environment (M-3).
- The published macOS script reproduces every customer report on the lab Mac (M-5).
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
