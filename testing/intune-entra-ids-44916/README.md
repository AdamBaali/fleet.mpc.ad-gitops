# Intune and Entra device IDs on Windows hosts (fleetdm/fleet#44916)

`customer-cisneros-w` runs fleetd agent-only on Windows, next to Intune. Serial, hostname and hardware UUID collide over time, so they want the Intune device ID and the Entra device ID per host as a stable join key.
Product folded the request into fleetdm/fleet#43723, which lifted the report row cap in 4.93. This project checks that a stored report gives both IDs per host through the API.

Status (2026-11-09): research done. Query logic and five negative controls pass on a lab VM with faked IDs (T-1, T-2). The stored report test (T-3) waits for the lab fleet. No Entra or Intune tenant is available, so the real-host check is blocked. See [HANDOFF.md](HANDOFF.md).

| File | What it is |
| --- | --- |
| [NOTES.md](NOTES.md) | Where Windows stores each ID, with sources, and the risks |
| [TEST_PLAN.md](TEST_PLAN.md) | Every test, how it runs and how it passes |
| [RESULTS.md](RESULTS.md) | One entry per test |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| [ISSUE_UPDATE.md](ISSUE_UPDATE.md) | Draft update for the issue. Adam posts it |
| `queries/` | The report SQL. Tested on faked data only: don't send to the customer before T-4 |
| `scripts/fake-ids.ps1` | Writes and removes fake Intune and Entra keys and certificates on the VM |
| `scripts/run-t1-t2.sh`, `vm-query.sh` | Run T-1 and T-2 with evidence |
| `test-evidence/lab/` | Outputs, one folder per test |
| `../../fleets/device-ids-lab.yml` | The lab fleet with both reports (`lib/windows/reports/device-ids.reports.yml`) |

## Findings so far

1. The Intune device ID is the `EntDMID` registry value the customer already reads. Stock osquery can read it.
2. The issue is wrong about the Entra device ID. There is no `DeviceId` value under `CloudDomainJoin\JoinInfo`. The ID is the subject of the device certificate that the `JoinInfo` subkey name (a thumbprint) points to. Fleet already reads it this way.
3. Fleet already collects the Entra device ID on Windows, but only when Microsoft conditional access is on, and it doesn't show it on the host API. That gap is the original ask.

No customer or person names in this folder. Internal links are in `private/`, which git ignores.
