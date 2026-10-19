# macOS Power Nap: software installs and scripts (fleetdm/fleet#46924)

Tests what fleetd does when a policy automation installs software or runs a script while a Mac laptop is asleep with the lid closed. Fleet asked for fleetd logs of this for story fleetdm/fleet#48898. Same method as `../_framework`. Work in progress.

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [RESULTS.md](RESULTS.md) | One entry per test run |
| [NOTES.md](NOTES.md) | Desk findings, open questions, lab versus production |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| [ISSUE_UPDATE.md](ISSUE_UPDATE.md) | Draft update for the issue, for review (not posted) |
| `test-evidence/desk/` | Code and thread review |
| `test-evidence/mac/` | Runs on the Mac laptop (created on the first run) |

Status (2026-10-19): folder and plan created. Desk review done (D-1). No runs on a Mac yet.
