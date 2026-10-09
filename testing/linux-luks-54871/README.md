# Linux and LUKS: test results (fleetdm/fleet#54871)

Tests the Linux disk encryption guides against the three questions in the issue: removing the end user's LUKS key, whether LUKS invalidates any key, and key escrow on Arch Linux. Same method as `../conditional-access-54654` and `../_framework`. Work in progress.

**Start here:** [EVIDENCE.md](EVIDENCE.md).

| File or folder | What it is |
| --- | --- |
| [EVIDENCE.md](EVIDENCE.md) | Generated page: every test, result, pictures, links to outputs |
| [RESULTS.md](RESULTS.md) | Desk findings and one entry per test run |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [VM_PLAN.md](VM_PLAN.md) | Which distros Fleet supports (docs, code, open PRs) and which VMs to build |
| [ISSUE_UPDATE.md](ISSUE_UPDATE.md) | Draft update for the issue, for review (not posted) |
| [NOTES.md](NOTES.md) | Open items |
| `test-evidence/` | `desk/` (docs and code), `ubuntu/` (installer pages, first boot) |

Status (2026-10-09): desk review done (Q3: Arch is not supported). Ubuntu installed per the guide; first boot blocked by a display problem. The key slot tests have not started.
