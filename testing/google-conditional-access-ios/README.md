# Google conditional access for iPhones: test results

Testing the draft guide "Conditional access: Google" ([fleetdm/fleet#55107](https://github.com/fleetdm/fleet/pull/55107))
for a customer request (customer-antonella). Built-in support is tracked in [fleetdm/fleet#54888](https://github.com/fleetdm/fleet/issues/54888).
Work in progress. Same method as `../conditional-access-54654` and `../_framework`.

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [RESULTS.md](RESULTS.md) | One entry per test run so far |
| [GUIDE-FINDINGS.md](GUIDE-FINDINGS.md) | What the tests showed about the guide |
| [NOTES.md](NOTES.md) | What was not done and how the lab differs from production |
| `test-evidence/admin-console/` | Window screenshots of the Google Admin console (setup, access level) |

Status (2026-10-09): Google test org, OU, mobile management check, Enterprise Standard upgrade and the access level are done.
iPhone, Fleet fleet, sync script and sign-in tests are next.
