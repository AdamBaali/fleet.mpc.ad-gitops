# R-1: Script lint and mock run
Script: `sync-fleet-hosts-to-google.sh` from PR fleetdm/fleet#55107 head (copy in `script-under-test.sh`).
Method: a fake `curl` on `PATH` (`mock/bin/curl`) serves made-up Fleet and Google JSON (`mock/*.json`, fake
`lab.test` emails, no real data) and logs every call (`02-mock-calls.txt`). Run: `DRY_RUN=false`.

| Case | Mock data | Seen | OK |
|---|---|---|---|
| Email case differs (E-5) | Fleet `UserA@Lab.test`, Google `usera@lab.test` | Matched | Yes |
| iPhone and iPad for one user | host 1 ios, host 2 ipados | Separate keys, iPad marked MANAGED | Yes |
| Already MANAGED (E-11) | `state-A1` | No write | Yes |
| Not in Fleet (C-2) | userb | No write, stays without state | Yes |
| MDM off in Fleet (E-3) | host 3 `Off` | Not managed | Yes |
| "On (personal)" BYOD | host 4 | Managed | Yes (by design, `startswith("On")`) |
| Two iPhones in Fleet and Google (E-4) | usere | "Review" line, no write | Yes |
| No email in Fleet (E-6) | host 7 `device_mapping: null` | Ignored | Yes |
| Same email from two sources | userg idp + custom | Deduplicated, managed | Yes |
| Host removed from Fleet (E-2) | `state-R1` MANAGED, no host | MANAGED -> UNMANAGED | Yes |
| Windows device in Google | W1 | Ignored | Yes |
| Google paging (E-9) | 2 pages, `nextPageToken` | Both pages read | Yes |
| **Old iPhone still in Google** | userd: 1 Fleet host, 2 Google iPhones | "Review", new phone NOT managed | **Finding** |
| **Google write fails (E-8)** | PATCH returns 403 | First write fails, exit 22, earlier writes kept | Finding (acceptable) |

Findings:
1. When an end user replaces their iPhone, the old one stays in Google, and the new phone stays blocked until an
   admin deletes the old device in Google Admin. The guide should say so (Troubleshooting).
2. A failed state read (any error, not only 404) counts as "no state", and a failed write stops the run with a
   non-zero exit. The Action shows a failure, the next run carries on. Fine for a workaround, worth a line.
3. `device_mapping` counts every source (`mdm_idp_accounts`, `idp`, `custom`, `google_chrome_profiles`). A custom
   email set by an admin is trusted the same as IdP. Worth one line in Prerequisites.

Not covered by mocks: real Google field values (`deviceType`, `model` for iPhone/iPad), whether PATCH creates a
state that doesn't exist yet, the customer ID "C" prefix, and the long-running Operation. Those need the live test.

## Result: PASS
