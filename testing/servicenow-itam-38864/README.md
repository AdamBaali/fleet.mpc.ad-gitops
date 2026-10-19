# Software fields for a Fleet to ServiceNow ITAM export (fleetdm/fleet#38864)

Tests which software fields Fleet can give ServiceNow on each OS, as a stopgap until Fleet exports them itself. Focus: install date and publisher (#54912, #54914), which Fleet doesn't return yet, and checking the last opened dates it does return. Same method as `../_framework`. Work in progress.

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [NOTES.md](NOTES.md) | What each OS can give, exporter design, risks |
| [RESULTS.md](RESULTS.md) | One entry per test run |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| `test-evidence/` | Outputs, one folder per test (created on the first run) |

Status (2026-10-19): plan, reports and lab fleet drafted and checked against Fleet 4.93.0 source. Linux queries ran in osquery. Nothing applied to Fleet yet.

No customer or person names in this folder. Refer to the request by its public issue numbers only.
