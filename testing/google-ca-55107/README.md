# Google conditional access for iPhones: test results (fleetdm/fleet#55107)

Tests the draft guide "Conditional access: Google" ([PR #55107](https://github.com/fleetdm/fleet/pull/55107)) and its sync script.
Google Context-Aware Access blocks sign-in from iPhones and iPads that aren't managed by Fleet. Built-in support is tracked in
[fleetdm/fleet#54888](https://github.com/fleetdm/fleet/issues/54888). Same method as `../conditional-access-54654` and `../_framework`.

**Start here:** [EVIDENCE.md](EVIDENCE.md), every test with its result, photos and links to the raw output.

| File or folder | What it is |
| --- | --- |
| [EVIDENCE.md](EVIDENCE.md) | Generated page: every test, result, pictures, links to outputs |
| [TESTING-LOG.md](TESTING-LOG.md) | Everything tried on the live test, in order, with results |
| [RESULTS.md](RESULTS.md) | One line per test, plus the findings |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [GUIDE-FINDINGS.md](GUIDE-FINDINGS.md) | What the tests showed about the guide, with proposed edits |
| [REPORTING.md](REPORTING.md) | How Fleet, the sync script, Google and GitHub Actions report to each other |
| [RUNBOOK.md](RUNBOOK.md) | The iPhone test, in order |
| [NOTES.md](NOTES.md) | What was not done and how the lab differs from production |
| `proposed/` | The corrected sync script and the diff against the draft |
| `scripts/` | Lab helpers (`google-token.sh`, `clientstate_test.py`) |
| `test-evidence/` | `desk/`, `admin-console/`, `cloud/`, `fleet/`, `iphone/`, `github/`: raw output and window screenshots |

Fleet side: `../../fleets/ios-google-lab.yml` ("iOS Google Lab") and the workflow `../../.github/workflows/google-sync.yml` (one sync every 5 minutes).
Status (2026-10-09 evening): the guide's flow works with fixes. The sync works after two script fixes and one workflow fix. No named
`device.vendors` key works, but the keyless `exists()` condition lets the Fleet-managed iPhone in (C-1e) and blocks a user Fleet never
marked (C-2). E-2 (Fleet stops counting the phone) in progress. Full timeline: [TESTING-LOG.md](TESTING-LOG.md). Key question open with Google.
