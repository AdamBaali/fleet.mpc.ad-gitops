# Test plan: fleetd health check scripts

Pull request: https://github.com/fleetdm/fleet/pull/59727 · Environment: lab Fleet; Windows host 37 and Linux
host 38 in Device IDs Lab (id 15), macOS host 12 in Ping Duo Lab (id 4) · Started: 2026-11-24

## Scope
All three scripts, run through Fleet as root/SYSTEM. The pull request
changes these Windows results:
- `secret.txt` missing: `[FAIL]` becomes `[INFO]`. Orbit moves the enroll secret into Credential Manager and deletes
  the file after enrolling.
- `HKLM\SOFTWARE\FleetDM\Orbit` missing: `[WARN]` becomes `[INFO]`.
- Stopped automatic-start services: `[WARN]` becomes `[INFO]`.
- osqueryd must run from `C:\Program Files\Orbit`.
- New: MDM enrollment details and a Fleet server reachability check.
- The archive path prints after the result, once the archive exists.

## Environment
| Item | Value |
|---|---|
| Fleet | Lab Fleet, Premium |
| Hosts | Host 37: Windows 11 Pro 26H2 (10.0.26300) arm64 QEMU VM, fleetd 1.64.0, osquery 5.24.1, Fleet MDM on (manual) |
| How the script runs | Saved script in fleet 15 (GitOps), run through `POST /api/v1/fleet/scripts/run` as SYSTEM |
| Lab differences from production | Customers run the script by hand in an elevated PowerShell, not as SYSTEM. arm64 only, no x64 host |

## Tests
| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| T-1 | Baseline | Live query host 37 for `secret.txt`, node key, the Orbit registry key, foreign osqueryd, and existing archives | Healthy: node key present, `secret.txt` and registry key absent, no archives | Rows match |
| T-2 | Scripts saved | Merge, let GitOps apply, list scripts in fleet 15 | Both scripts listed | `run-script.sh` finds both by name |
| T-3 | Negative control | `tools/run-script.sh 37 fleetd-healthcheck-main.ps1` | `[FAIL] enroll secret not found`, `[WARN] Registry key not found` | Both lines in the output |
| T-4 | Pull request version | `tools/run-script.sh 37 fleetd-healthcheck.ps1` | No `[FAIL]` lines; `secret.txt` and registry lines are `[INFO]`; MDM section lists the enrollment; Fleet server reachable; `Result: ALL CHECKS PASSED`; exit code 0 | All true |
| T-4b | MDM enrollment filter | Re-run T-4 after the filter fix | MDM section lists only the Fleet enrollment | No "Authority" lines |
| T-5 | Archive | List `C:\Windows\Temp\fleetd_healthcheck_*` after T-4 | One archive per run, no leftover work folders | Archives present with the run times |
| T-6, T-7 | Windows after review fixes | `tools/run-script.sh 37 fleetd-healthcheck.ps1` | As T-4 | All true |
| L-1 to L-3 | Linux | `tools/run-script.sh 38 fleetd-healthcheck.sh` on a Docker Ubuntu 24.04 host with systemd and a real fleetd `.deb` | No `[FAIL]`, exit 0 | `ALL CHECKS PASSED` |
| M-1 to M-4 | macOS | `tools/run-script.sh 12 fleetd-healthcheck.sh 4` on the lab Mac | No `[FAIL]`, exit 0, within Fleet's 5-minute limit | `ALL CHECKS PASSED` |
| M-5 | macOS negative control | `tools/run-script.sh 12 fleetd-healthcheck-main.sh 4` | The customer-reported bugs | Errors present |

## Out of scope / not tested
- Running by hand in an elevated session (no console access from the cloud session). Do it on the VM over VNC if needed.
- x64 Windows and Windows Server.
- The archive's contents: the archive stays on the VM.
