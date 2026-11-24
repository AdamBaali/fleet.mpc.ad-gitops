# Results: fleetd health check scripts

## T-1 Baseline
## Result: PASS
2026-11-24, live query on host 37 (online):

| Item | Value |
|---|---|
| `C:\Program Files\Orbit\secret.txt` | absent |
| `secret-orbit-node-key.txt`, non-empty | present |
| `HKLM\SOFTWARE\FleetDM\Orbit` | absent |
| `Fleet osquery` service `Environment` value | present |
| osqueryd running outside `C:\Program Files\Orbit` | none |
| MDM enrollment keys with a `ProviderID` | 4 |
| `fleetd_healthcheck_*` in `C:\Windows\SystemTemp` or `C:\Windows\Temp` | none |

## T-2 Scripts saved
## Result: PASS
After GitOps applied, fleet 15 lists `fleetd-healthcheck-main.ps1` (id 121) and `fleetd-healthcheck.ps1` (id 122).

## T-3 Negative control
## Result: PASS
[test-evidence/windows/T-3-main-script.txt](test-evidence/windows/T-3-main-script.txt). The published script on the
healthy host reports `[FAIL] enroll secret not found` and `[WARN] Registry key not found`, ends with
`ONE OR MORE CHECKS FAILED`, and exits 1. It prints the archive path before the archive exists, under an empty
"Packaging archive" header.

## T-4 Pull request version
## Result: PASS
[test-evidence/windows/T-4-pr-script.txt](test-evidence/windows/T-4-pr-script.txt). Same host, two minutes later: no
`[FAIL]` lines, the secret and registry lines are `[INFO]`, `ORBIT_EUA_TOKEN` is redacted, the Fleet server answers
`/healthz` with 200, `ALL CHECKS PASSED`, exit code 0, runtime 5 s.

One flaw: the MDM section also listed the built-in Local, Cloud and Deploy Authority entries, which have a
`ProviderID` but no server URL. The pull request now lists only entries with a server URL. T-4b re-runs it.

## T-4b MDM enrollment filter
## Result: NOT-RUN

## T-5 Archive
## Result: PASS
[test-evidence/windows/T-5-archives.txt](test-evidence/windows/T-5-archives.txt). Both archives are in
`C:\Windows\Temp`, with no work folders left behind. The pull request archive holds `summary.txt` and the new
`logs\mdm\dsregcmd_status.txt` and `logs\mdm\mdm_admin_events.csv`.

Live queries on the `file` table timed out on host 37 after the runs, even for a known path, while `SELECT 1`
answered. A read-only Fleet script listed the archives instead.
