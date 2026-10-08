# Linux and LUKS: test results (fleetdm/fleet#54871)

Work in progress. Tests the Linux disk encryption guides against the three questions in the issue: removing the end
user's LUKS key, whether LUKS invalidates any key, and key escrow on Arch Linux.

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [RESULTS.md](RESULTS.md) | Desk findings and one entry per test run so far |
| [NOTES.md](NOTES.md) | Open items |
| `test-evidence/` | Window-only screenshots. `ubuntu/S-1-installer/` is the guide's install steps, `ubuntu/S-8-first-boot/` is the blocked first boot |

Status (2026-10-08): the Ubuntu install with encryption is done. The first boot shows a black display, so the escrow
and key slot tests haven't started. Nothing in this folder is a final result. The Fleet-side reading (docs and code) is in RESULTS.md.
