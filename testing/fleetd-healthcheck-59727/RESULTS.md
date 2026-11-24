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
## Result: PASS
[test-evidence/windows/T-4b-pr-script-mdm-filter.txt](test-evidence/windows/T-4b-pr-script-mdm-filter.txt). After the fix,
the MDM section lists only the Fleet enrollment. Still `ALL CHECKS PASSED`, exit code 0.

## T-5 Archive
## Result: PASS
[test-evidence/windows/T-5-archives.txt](test-evidence/windows/T-5-archives.txt). Both archives are in
`C:\Windows\Temp`, with no work folders left behind. The pull request archive holds `summary.txt` and the new
`logs\mdm\dsregcmd_status.txt` and `logs\mdm\mdm_admin_events.csv`.

Live queries on the `file` table timed out on host 37 after the runs, even for a known path, while `SELECT 1`
answered. A read-only Fleet script listed the archives instead.

## T-6 Windows, after the review fixes
## Result: PASS
[test-evidence/windows/T-6-pr-script-review-fixes.txt](test-evidence/windows/T-6-pr-script-review-fixes.txt). Process
lines show executable paths, not command lines. `ALL CHECKS PASSED`, exit code 0, runtime 4 s.

## T-7 Windows, final
## Result: PASS
[test-evidence/windows/T-7-final.txt](test-evidence/windows/T-7-final.txt). Same result after the macOS and Linux fixes.

## L-1 Linux, first run
## Result: FAIL
[test-evidence/linux/L-1-pr-script.txt](test-evidence/linux/L-1-pr-script.txt). Host 38: Ubuntu 24.04.5 in Docker with
systemd, fleetd 1.64.0 `.deb` built with `fleetctl package`, enrolled in fleet 15. The script reported
`[FAIL] enroll secret not found: /opt/orbit/secret.txt`. The `.deb` keeps the secret in `/etc/default/orbit`
(`ORBIT_ENROLL_SECRET`), so every Linux host would fail. Everything else passed, including the reachability check
through the package's own CA file (`ORBIT_FLEET_CERTIFICATE`).

## L-2 and L-3 Linux, after the fixes
## Result: PASS
[L-2](test-evidence/linux/L-2-final.txt), [L-3](test-evidence/linux/L-3-final.txt). The secret check accepts
`/etc/default/orbit`, process lines show PID and executable, orbit is matched by folder. `ALL CHECKS PASSED`, exit 0.
The remaining warnings (package events, a failed `getty-static` unit, journal errors) come from the container.

## M-1 macOS, first run
## Result: FAIL
[test-evidence/macos/M-1-pr-script.txt](test-evidence/macos/M-1-pr-script.txt). The lab Mac (macOS 27.2.1, fleetd 1.64.0).
Fleet killed the script at its 5-minute limit. The unified log search on message text returned 824,822 lines for 72h,
and the system-wide error/fault search took about 2 minutes. Over 100 launchd jobs were listed with exit status -9,
which is launchd stopping idle daemons.

## M-2 and M-3 macOS, faster log searches
## Result: FAIL
[M-2](test-evidence/macos/M-2-final.txt), [M-3](test-evidence/macos/M-3-final.txt). Runtime dropped to 42 s, but
`[FAIL] orbit is NOT running`. macOS `pgrep` skips its own ancestors, and orbit is an ancestor when Fleet runs a
script. A diagnostic run also showed that macOS `pgrep -lf` prints osqueryd's environment, including the enroll
secret; the first pull request version wrote that output to `summary.txt`.

## M-4 macOS, final
## Result: PASS
[test-evidence/macos/M-4-final.txt](test-evidence/macos/M-4-final.txt). `pgrep -a` finds orbit, the foreign-osqueryd
check uses executable paths, and no secret appears. `ALL CHECKS PASSED`, exit 0, runtime 41 s.

## M-5 macOS negative control
## Result: PASS
[test-evidence/macos/M-5-main-negative-control.txt](test-evidence/macos/M-5-main-negative-control.txt). The published
script on the same Mac reproduces the customer reports: it finishes in 0 s because `log()` shadows `/usr/bin/log` and
no logs are collected, prints `0 0: syntax error in expression`, raw colour codes, and
`tee: summary.txt: No such file or directory`, and exits 1 without a result line.

## Timing on the lab Mac (read-only diagnostic)
| Unified log search, 72h | Time | Lines |
|---|---|---|
| Message text contains orbit, osquery or fleet (first version) | over 3 min | 824,822 |
| Processes running from `/opt/orbit/` (final) | 15 s | 362,897 |
| Error/fault, whole system | 108 s | 1,221,263 |
| Error/fault, fleetd processes only (final) | 9 s | 79 |

## T-8 Windows, after the --insecure fix
## Result: PASS
[test-evidence/windows/T-8-insecure-flag.txt](test-evidence/windows/T-8-insecure-flag.txt). `--insecure="False"` no
longer counts as insecure mode. Host 37 has no `--insecure`, so its result is unchanged: `ALL CHECKS PASSED`, exit 0.
The final GitOps copies of all three scripts are identical to the pull request head.

## T-9, L-4, M-6 Second review round
## Result: PASS
[T-9](test-evidence/windows/T-9-review2.txt), [L-4](test-evidence/linux/L-4-review2.txt),
[M-6](test-evidence/macos/M-6-review2.txt). After the second round of review fixes (processes confirmed by executable
path, systemd-style parsing of `/etc/default/orbit`, `ORBIT_INSECURE` read as orbit reads it), all three hosts report
`ALL CHECKS PASSED` with exit code 0 (4 s, 1 s, 44 s). On the Ubuntu host, an env file with quoted values,
`ORBIT_INSECURE=1`, and the enroll secret split across a backslash continuation gave a redacted secret in both the output
and the archive, and `--cacert` plus `-k` on the probe.

## M-7, L-5 Unchecked success messages
## Result: PASS
[M-7](test-evidence/macos/M-7-unchecked-ok.txt), [L-5](test-evidence/linux/L-5-unchecked-ok.txt). Removing `set -e`
left steps that printed "Collected" or "Grepped" whatever the command before them returned. An audit of both shell
scripts found four more besides the Fleet Desktop copy that review flagged: the plist read (macOS), `last` (both) and
the syslog grep (Linux). Each now checks its result. Both hosts still report `ALL CHECKS PASSED`, exit 0 (44 s, 1 s).
