# Testing log: Google conditional access for iPhones (fleetdm/fleet#55107)

Everything tried, in order, with what happened. Times are UTC on 2026-10-09 unless noted. Evidence paths are under `test-evidence/`.
Lab: Fleet 4.92.3 (`fleet.mpc.ad`, fleet **iOS Google Lab**), Google Workspace **Enterprise Standard** trial on a lab domain, test OU
**Fleet iOS test**, one iPhone 15 Pro Max on iOS 26.6.1 (the tester's own phone), Google Drive app as the test app.

## Summary
| Part of the guide | Result | Short version |
|---|---|---|
| Fleet side (API user, host, email) | Works | One deviation: email set as a custom mapping (no IdP) |
| iPhone appears in Google | Works | Sign in to Drive; basic mobile management adds it |
| Sync script as written | **Fails** | HTTP 400 on the first write: two bugs |
| Sync script fixed | Works | Writes MANAGED/COMPLIANT; Google console shows "fleet (custom)" |
| GitHub Action as written | **Fails** | `google-github-actions/auth` DWD token: HTTP 400 |
| GitHub Action fixed | Works | JWT signed in the job |
| Access level + test OU + iPhone | Works | Drive opens with a non-Fleet diagnostic condition |
| **Access level reading the Fleet state** | **Fails** | Denied with `device.vendors["fleet"]` and `device.vendors["<id-without-C>-fleet"]` while the state is MANAGED |

Bottom line so far: the sync works after two fixes, but Google does not let the customer-written client state satisfy the access level
for this iOS sign-in. One check left: a delay (Google documents 90 minutes for CrowdStrike signals). The question is open with Google.

## Log
| Time | What | Result | Evidence |
|---|---|---|---|
| 10-08 | Desk review: lint, mock run (14 cases), Fleet API fields, Google API reference | PASS, 5 desk findings | `desk/R-1-script-mock/` |
| 10-09 night | Google org, Business Plus has no Context-Aware Access; upgraded to Enterprise Standard | PASS after upgrade | `admin-console/G-1b-*` |
| 10-09 night | OU, test users, access level (guide's CEL accepted), Cloud project, service account, delegation (first `unauthorized_client`), API-only Fleet user, DRY_RUN with 0 devices | PASS | `admin-console/`, `cloud/`, `fleet/` |
| 08:39 | GitOps apply for the new fleet: failed twice (missing enroll secret, then the other lab's SCEP tunnel down). Fixed, fleet created | PASS | — |
| 08:55 | iPhone enrolled with the fleet link. Page defaulted to **Company-owned**; status `On (manual)` | PASS | `iphone/G-5-enroll/` |
| 08:56 | Email set with `PUT /hosts/:id/device_mapping` (custom). Sync user sees it | PASS (deviation) | `iphone/G-5-enroll/` |
| 08:58 | Drive sign-in as the managed user: "Device info syncing", then **"Your organisation isn't allowing access"**. Device in Google, model "iPhone 15 Pro Max" | PASS (blocked before sync, expected) | `iphone/G-6-google-device/` |
| 08:59 | PR script DRY_RUN: `none -> MANAGED` | PASS | `iphone/C-1a-*/01` |
| 09:00 | PR script LIVE: **HTTP 400**, exit 56, nothing written | **FAIL** | `iphone/C-1a-*/02` |
| 09:00 | Tried 4 partner ID and `customer=` combinations: only `<id-without-C>-fleet` + `customers/my_customer` works | Cause found | `iphone/C-1a-*/03` |
| 09:03 | Phone still blocked (access level had the guide's with-C key) | Expected | `iphone/C-1a-*/04` |
| 09:05 | Access level key changed to `<id-without-C>-fleet`. Retries to 09:10: blocked. Log: no new entry (Drive replayed the old denial) | Inconclusive | `iphone/C-1c-*` |
| 09:33 | Access level changed to an OR of 4 key forms. Retries: blocked | Inconclusive (see 10:59 note) | `iphone/C-1c-*` |
| 09:35 | Admin console device page: **Third-party services "fleet (custom)"**, Managed, Compliant, ID = Fleet host ID | Google stores the state | `iphone/C-1b-*` |
| 09:50 | Checked Admin console: access level assigned at the **top-level OU** for Admin Console, Drive and Gmail (lockout risk). Third-party integrations: "None connected" (partner list only). Licences: 3 assigned. Audit report "not available" on the trial | Found a scope problem | `iphone/C-1c-*` |
| 10:40 | Assignment moved to the test OU only (Drive and Gmail, Active, apply to desktop and mobile apps) | Fixed | `iphone/C-1c-*` |
| 10:45 | Log: **Access Denied** (re-evaluated) | FAIL | `admin-console/C-1d-*` |
| 10:59 | Diagnostic condition `device.is_admin_approved_device == true`. Condition box was seen **empty** before pasting, so the OR test is uncertain | — | — |
| 11:00 | Sign out, sign in: **"Access evaluated", satisfied. Drive opens** | **Level, OU and phone work** | `iphone/C-1c-*/01`, `admin-console/C-1d-*` |
| 11:05 | Fixed script (no-C partner ID, `my_customer`, empty-Fleet guard): `UNMANAGED -> MANAGED`, read back OK, second run no-op | PASS | `iphone/C-1b-*` |
| 11:07 | GitHub Action as the guide writes it: **auth step HTTP 400**, three runs | **FAIL** | `github/G-7-*` |
| 11:08 | Condition `device.vendors["fleet"].is_managed_device == true`: **blocked again within seconds** (live) | **FAIL** | `iphone/C-1c-*/02` |
| 11:20 | Condition saved with literal placeholder text by mistake | Not a test | `iphone/C-1c-*/03` |
| 11:23 | GitHub Action with the JWT step: **success** (3 runs, no changes needed) | PASS (workaround) | `github/G-7-*` |
| 11:28 | Condition `device.vendors["<id-without-C>-fleet"].is_managed_device == true` | — | — |
| 11:31 | Drive briefly showed its home screen while the phone was offline (cache), then blocked again on 5G | Not an allow | — |
| 11:44 | Sign-in logged: **Access Denied**, unsatisfied | **FAIL** | `admin-console/C-1d-*` |
| after 12:40 | Re-check with the state MANAGED for over 90 minutes | Pending | — |

## What we know works, and what doesn't
- **Works:** Fleet API (List hosts with `device_mapping`), matching by email and device type, writing the client state (after the fixes),
  GitHub Actions (after the fix), Context-Aware Access on the test OU, and the iPhone passing a condition on data Google collects itself.
- **Doesn't:** an access level condition on `device.vendors[...]` that reads the customer-written client state. Google shows the state in
  the console but the condition stays unsatisfied for both documented key forms.
- **Docs:** every `device.vendors` example in Google's docs uses a BeyondCorp Alliance partner name (Lookout, CrowdStrike, Tanium, PANW,
  Check Point). The only line about customer-written states is in the clientStates reference: the suffix "is used in setting up Custom Access
  Levels". `device.vendors` is Pre-GA. No public example of a customer-written state satisfying an access level was found.

## Open questions for Google
1. Which CEL key reads a customer-owned client state (`ownerType OWNER_TYPE_CUSTOMER`, partner `<id-without-C>-fleet`, shown as "fleet (custom)")?
2. Does it apply to Workspace mobile apps on iOS with basic mobile management?
3. How long after a `clientStates.patch` does Context-Aware Access use the new state?

## Deviations from the guide
- End user email set as a custom mapping, not end user authentication.
- The tester's own phone, enrolled as Company-owned (manual), not BYOD.
- Drive instead of Gmail (Gmail needs MX records on the lab domain).
- Script and workflow fixed to get past the two failures above (diffs in `../../fleets/ios-google-lab/google-sync/` and `../../.github/workflows/google-sync.yml`).
