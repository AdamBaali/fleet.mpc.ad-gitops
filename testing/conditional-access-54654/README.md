# Conditional access guides: test results (fleetdm/fleet#54654)

Testing of the PingFederate and Duo guides in [PR #54346](https://github.com/fleetdm/fleet/pull/54346).

**Start here:** [EVIDENCE.md](EVIDENCE.md) lists every test with its result, pictures and links to the raw output.
The reusable method is in [`../_framework`](../_framework).

| File or folder | What it is |
| --- | --- |
| [EVIDENCE.md](EVIDENCE.md) | Generated page: every test, result, pictures, links to outputs |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [RESULTS.md](RESULTS.md) | Running log of every test and incident |
| [GUIDE-FINDINGS.md](GUIDE-FINDINGS.md) | What the tests showed about each guide |
| [NOTES.md](NOTES.md) | What was not tested and how the lab differs from production |
| `test-evidence/` | Raw output and pictures (`linux/`, `macos/`, `console/`, `renewal/`) |
| `lab-setup/` (ping, stepca, est, duo, linux-vm), `tests/`, `tools/` | Scripts and helpers used to build the lab |
