# Test plan: Google conditional access for iPhones (fleetdm/fleet#55107)

**Status (2026-10-09):** run. Results in [RESULTS.md](RESULTS.md), findings in [GUIDE-FINDINGS.md](GUIDE-FINDINGS.md). This is the plan as written before the live test.

Guide under test (draft, PR fleetdm/fleet#55107): `articles/google-conditional-access-integration.md`,
`docs/solutions/api-scripts/sync-fleet-hosts-to-google.sh`, the Google line in `articles/conditional-access.md`.
Method: `../_framework/README.md`. One folder per test in `test-evidence/<group>/<ID>-<slug>/`, raw output plus
window-only pictures, secrets and emails masked, a verdict per test, failures recorded before fixing.

How the guide works (from the PR): an iPhone signs in to a Google app, Google's basic mobile management adds it to
Google. A script runs every 5 minutes, matches Google iOS devices to Fleet hosts by end user email and device type
(iPhone or iPad), and writes `clientStates` under partner ID `<customer-ID>-fleet` with `managed` and
`complianceState`. A custom Context-Aware Access level checks
`device.vendors["<customer-ID>-fleet"].is_managed_device == true`. `device.vendors` is a Google Preview feature.

## What we need (blockers first)
| Need | Status |
| --- | --- |
| A real iPhone (an iPad too if possible). The iOS Simulator can't enroll in MDM or install Google apps with a managed sign-in | Done: iPhone 15 Pro Max. No iPad |
| Google Workspace Enterprise Standard/Plus/Education, or Cloud Identity Premium, with a super admin (test org, not production) | Done: Enterprise Standard trial |
| A test OU, and 2 test users in it (one managed iPhone, one unmanaged) with Google accounts the tester controls | Done |
| Fleet side: `fleet.mpc.ad` has Apple MDM and ABM on. New fleet "iOS Google Lab" in the GitOps repo, iPhone enrolled, end user email in Fleet | Done |
| End user email in Fleet: end user authentication (IdP) or a custom mapping. The lab Fleet has no IdP configured | Custom mapping, then an IdP username set by API (NOTES.md) |
| API-only Fleet user (Observer, only List hosts), Google Cloud project, Cloud Identity API, service account, domain-wide delegation | Done |

## Desk review (before touching Google)
| ID | Check | Expected |
| --- | --- | --- |
| R-1 | `bash -n`, `shellcheck`, and the script's matching logic against mock Fleet and Google data | Clean, or findings |
| R-2 | Fleet side of the script: `GET /hosts?device_mapping=true`, `platform` `ios`/`ipados`, `mdm.enrollment_status` starts with "On", `device_mapping[].email` | Fields exist in 4.92 (`device_mapping` and "On (manual)" and "On (automatic)" are documented). Check which `device_mapping` sources show up for an iPhone with IdP end user auth |
| R-3 | Google API: `devices.list` with `view=USER_ASSIGNED_DEVICES`, `deviceUsers.list`, `clientStates.patch` (needs `updateMask`, `customer`), `deviceType`/`model` fields for iOS, `partner ID` format rules | Confirm each against Google's reference, quote it |
| R-4 | CEL condition `device.vendors["<id>"].is_managed_device` and the Preview status, which editions support it | Confirm in Google docs |
| R-5 | Rest of the script (after `Run`: the `clientStates.patch` call) and error handling, `google_list` paging, exit codes | Read in full, note issues |
| R-6 | Guide wording against Fleet's style (short plain sentences, sentence case headings) | List edits |

## Setup (follow the guide word for word)
| ID | Test | Expected |
| --- | --- | --- |
| G-1 | Prerequisites list: edition, basic mobile management for iOS on, MDM enrolled iPhone with end user email | Each item verified or flagged |
| G-2 | Step 1: Observer API-only user limited to List hosts | Token works for `GET /hosts`, fails elsewhere |
| G-3 | Step 2: project, Cloud Identity API, service account key, domain-wide delegation with the `cloud-identity.devices` scope, admin to act as | Access token obtained for the admin |
| G-4 | Step 3.1-3.3: customer ID, script config, `DRY_RUN=true` run | Prints the intended changes, no writes |
| G-5 | iPhone enrolled in Fleet (manual enrollment is fine) and the end user email present in `device_mapping` | Host shows the email in Fleet |
| G-6 | iPhone signs in to a Google app (Gmail) with the test user | Device appears in Google Admin > Devices > Mobile & endpoints |
| G-7 | Step 3.4: GitHub Actions workflow exactly as written, in the lab GitOps repo, with secrets | Runs every 5 minutes. Record what breaks (the `auth` action needs `access_token_subject`) |
| G-8 | Step 4: access level with the CEL condition, assign to the test OU for Gmail and Drive, Apply to Google desktop and mobile apps | Level saved, assigned |

## Core flow (the issue's pass/fail)
| ID | Test | Expected |
| --- | --- | --- |
| C-1 | Managed iPhone (in Fleet, synced): sign in to Gmail | Sign-in succeeds |
| C-2 | Unmanaged iPhone (not in Fleet): sign in to Gmail | Sign-in denied. Record the exact message the user sees |
| C-3 | Same two phones in Safari and Drive | Same results |
| C-4 | iPad managed and unmanaged, if a device is available | Same results |

## Edge cases
| ID | Test | Expected |
| --- | --- | --- |
| E-1 | Time from enrolling/signing in to "sign-in succeeds". Time from removing the host in Fleet to being blocked | Within about one sync (5 minutes) plus Google propagation. Record real numbers |
| E-2 | Remove the host from Fleet, run the sync | Client state becomes UNMANAGED, sign-in blocked |
| E-3 | Turn MDM off on the iPhone (unenroll), host still exists in Fleet | Record whether Fleet still counts it. Script checks `enrollment_status` starts with "On" |
| E-4 | Two iPhones for one user, or iPhone and iPad | "Review" line printed, device not marked managed. Guide says so |
| E-5 | Email in Fleet differs in case from the Google email | Matches (lowercased) |
| E-6 | Email missing in Fleet | Not matched, blocked. Guide's troubleshooting covers it |
| E-7 | User not in the test OU | Not affected |
| E-8 | Google token expiry, Fleet token wrong, Google 403 | Script exits non-zero, no partial writes. Record the output |
| E-9 | Many devices (paging): can't test live, read the code paths | Note in NOTES |
| E-10 | Access level assigned before the first sync | Everyone blocked until synced. Guide step order: does it warn? |
| E-11 | Re-run the script twice | No duplicate writes (idempotent) |
| E-12 | Device wiped and re-enrolled | New Google device, re-matched |
| E-13 | End user replaces their iPhone, old one still in Google | Mock: new phone stays blocked ("Review"). Guide should tell admins to delete the old device |

## Suspected guide issues to confirm
| Area | Issue to confirm | Proposed edit |
| --- | --- | --- |
| Step 3 | No step shows how to get a Google access token for local `DRY_RUN` runs | Add the command |
| Step 3 | Workflow uses `./sync-fleet-hosts-to-google.sh`, which isn't in the GitOps repo by default | Say where to put it |
| Step 4 | Order: turning on the access level before the first sync blocks everyone | Move or warn |
| Step 5 | The test table has no unmanaged-user setup and no "what the user sees" | Add |
| Prereqs | `device.vendors` is a Preview feature and edition limits | State the edition after R-4 |
| Prereqs | "end user's email in Fleet": which sources count (IdP, custom, Chrome profile) | Name them after R-2 |

## Done when
- Every test has a verdict. Failures are findings.
- The guide was followed start to finish with a real iPhone, deviations logged.
- Guide edits drafted in Fleet's style, as a local diff against a clone of the PR branch. Not pushed.
- `EVIDENCE.md` generated, update for the issue drafted, never posted. Teardown list in `HANDOFF.md`.

## Evidence capture (iPhone)
Every test that involves the phone has a screen recording (AirPlay or QuickTime), window-only PNGs, the Google Admin console view, the Fleet host page and the raw script output, saved as `test-evidence/<group>/<ID>-<slug>/` with a `result.md`. Emails and account names are masked.
