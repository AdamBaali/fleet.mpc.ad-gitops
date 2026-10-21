# macOS Power Nap: software installs and scripts (fleetdm/fleet#46924)

Tests what fleetd does when a policy automation installs software or runs a script while a Mac laptop is asleep with the lid closed. Fleet asked for fleetd logs of this for story fleetdm/fleet#48898. Same method as `../_framework`. Work in progress.

| File or folder | What it is |
| --- | --- |
| [EVIDENCE.md](EVIDENCE.md) | Every test with its result and evidence files (generated) |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [RESULTS.md](RESULTS.md) | One entry per test run |
| [NOTES.md](NOTES.md) | Desk findings, open questions, lab versus production |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| [ISSUE_UPDATE.md](ISSUE_UPDATE.md) | Draft update for the issue, for review (not posted) |
| `test-evidence/desk/` | Code and thread review |
| `test-evidence/mac/` | Runs on the MacBook Air |
| `scripts/build-pkg.sh` | Builds the fleetd installer for Power Nap Lab (secret read from Fleet) |
| `scripts/collect.sh` | Saves B-1 and each run's orbit and pmset logs for the same window |

Status (2026-10-21): D-1, B-1, C-1, PN-1 (reproduced) and PN-6 done. PN-2 partial, PN-2b (rerun) done: the small install fails too. PN-3 to PN-5 and PN-7 open.
