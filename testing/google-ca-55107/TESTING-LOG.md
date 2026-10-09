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
| **Access level reading the Fleet state** | **Works with a keyless condition** | Every named key fails, but `device.vendors.exists(k, device.vendors[k].is_managed_device == true)` lets the managed iPhone in |
| User without a Fleet state (C-2) | **Works** | Second account on the same iPhone: "Your organisation isn't allowing access" |
| Fleet stops counting the iPhone (E-2) | In progress | The Action wrote UNMANAGED; sign-in checks pending |

Bottom line: the sync works after two script fixes and one workflow fix, and Google stores the state ("fleet (custom)", Managed,
Compliant). No named `device.vendors["<key>"]` works on the iPhone (every documented and community form fails), but the keyless
`device.vendors.exists(k, device.vendors[k].is_managed_device == true)` does: the managed iPhone gets into Drive, and a user Fleet never
marked is blocked on the same phone (C-2). E-2 in progress.

## Update (2026-10-09 afternoon): it works without a key name
- `size(device.vendors) > 0`: **Drive opened.** The access level does see vendor data on the iPhone.
- `device.vendors.exists(k, device.vendors[k].is_managed_device == true)`: **Drive opened after sign-out and sign-in.** Fleet's
  `MANAGED` is read as `is_managed_device`. Only the key name was wrong.
- Still unknown: the key. Google rejects `contains` and list literals inside `exists()`, so it can't be searched for. The
  customer ID alone (`C<id>`, `<id>`, guarded with `in`) was also blocked.
- Caveat: the keyless condition trusts any third-party state that says managed (fine when Fleet is the only one).
- Still to test: C-2 (unmanaged user blocked) and E-2 (state set to UNMANAGED blocks the managed user).
- The sync runs on a schedule now: `.github/workflows/google-sync.yml`, every 5 minutes inside 30-minute runs (changed in the evening, below).

## Update (2026-10-09 evening): C-2 passes, E-2 under way
- **B-0** 15:31Z: with the keyless condition and the state MANAGED, the managed user signs in again and Drive opens.
- **C-2 passes** 15:39Z: the unmanaged user, added as a second account on the same iPhone, gets "Your organisation isn't allowing
  access". Google made a second device record for the phone; that user has no client states, so the condition is false.
- **E-2** 15:42Z: Fleet stops matching the phone (custom email changed to a dummy); the Action writes `MANAGED -> UNMANAGED` and the
  console shows Unmanaged. Sign-in checks and the way back are pending.
- Found while preparing E-2: removing the only managed iPhone from Fleet would leave it MANAGED (empty-Fleet guard), and the script
  prints end user emails in a public Actions log. Both in GUIDE-FINDINGS.md (26, 25).
- Workflow now: **one sync every 5 minutes** (a run takes about 15 seconds), log masked. Script: writes Fleet's serial number as the
  client state's asset tag (shown in the console) and prints a one-line summary on every run. It matches on the IdP email from
  enrollment only (`EMAIL_SOURCES`, default `mdm_idp_accounts`) and counts company-owned enrollments only (`ENROLLMENT_STATUSES`,
  default `On (automatic),On (manual)`). Managed phones without a usable email are flagged "No email". Checked on the mock (R-1c).
- 16:06Z the lab iPhone's IdP username set by API (`PUT /hosts/14/device_mapping`, `source: idp`); the API reports it as
  `mdm_idp_accounts`, so the lab now runs on the customer's path (IdP email) and no longer needs `custom`.
- 16:08Z sync token limited to List hosts (G-2b).

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
| 12:05 | Double-check: writes to the with-C partner ID get **403** (any `customer=`); any call with `customers/<customer-ID>` gets **400**. No-C partner ID confirmed | Confirmed | `iphone/C-1a-*` |
| 12:09 | Sign-in: **Access Denied** (no-C or `key-<id-without-C>` condition) | FAIL | `admin-console/C-1d-*` |
| 12:11 | Condition `device.vendors["key-<id-without-C>"]` (Google spec: "use the format key-acme where acme is the organization's customer ID") | Blocked | — |
| 12:14 to 12:39 | OR of 3 keys, then 6 terms (3 keys x `is_managed_device` / `is_compliant_device`), text verified by screenshot | Blocked; no log row | — |
| 12:25 | Admin console > Third-party integrations: partner list only (Lookout, Checkpoint, Omnissa, Jamf, CrowdStrike, Ivanti, Intune, Citrix). No custom option | Nothing to switch on | — |
| 12:30 | Community PR fleetdm/fleet#46454 says CEL reads suffix-first `device.vendors["fleet-<id-without-C>"]` (verified on macOS with Endpoint Verification). A write to that partner name gets 403 | Lead | — |
| 12:39 | Condition `device.vendors["fleet-<id-without-C>"].is_managed_device \|\| .is_compliant_device` | — | — |
| 12:44 | Sign-in logged: **Access Denied**. State MANAGED/COMPLIANT for 99 minutes | **FAIL** (not a delay) | `admin-console/C-1d-*` |
| 13:45 | Condition `size(device.vendors) > 0` | **Drive opened** | — |
| 13:47 | Condition `device.vendors.exists(k, device.vendors[k].is_managed_device == true)`; 13:51 sign-out and sign-in | **Drive opened** | `iphone/C-1e-*` |
| 13:53, 14:54 | `contains` and list literals inside `exists()` rejected by the console ("not allowed in comprehensions") | Can't narrow the key | — |
| 14:59 | Customer ID alone as the key (`C<id>`, `<id>`, guarded with `in`) | Blocked | — |
| 15:11 | Workflow on a schedule (30-minute runs, a sync every 5 minutes) | Done | — |
| 15:29 | Condition re-checked: the keyless `exists()` is saved | — | `iphone/C-1e-*/01` |
| 15:31 | B-0: managed user removed and signed in again, state MANAGED | **Drive opens** | `iphone/C-1e-*/02` |
| 15:32 | Scheduled run due: never started (GitHub best effort) | Note | — |
| 15:39 | C-2: unmanaged user added on the same iPhone | **Blocked** | `iphone/C-2-*` |
| 15:41 | Manual real sync with both users on the phone | No writes (correct) | `iphone/C-2-*` |
| 15:42 | E-2: Fleet email changed to a dummy; Action writes `MANAGED -> UNMANAGED`; console shows Unmanaged | PASS so far | `iphone/E-2-*` |

## What we know works, and what doesn't
- **Works:** Fleet API (List hosts with `device_mapping`), matching by email and device type, writing the client state (after the fixes),
  GitHub Actions (after the fix), Context-Aware Access on the test OU, and the iPhone passing a condition on data Google collects itself.
- **Doesn't:** a condition on a named key, `device.vendors["<key>"]`, reading the customer-written client state (the keyless `exists()` works). Google shows the state in
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
- E-2 makes Fleet stop counting the phone by changing its custom email, not by deleting it (finding 26).
- Script and workflow fixed to get past the two failures above (diffs in `../../fleets/ios-google-lab/google-sync/` and `../../.github/workflows/google-sync.yml`).

## Key forms tried (all with the state MANAGED/COMPLIANT)
| Key | Source | Result |
|---|---|---|
| `<customer-ID>-fleet` | The draft guide | Denied |
| `<id-without-C>-fleet` | clientStates reference (partner ID) | Denied (log 11:44) |
| `fleet` | Admin console label "fleet (custom)" | Blocked (live, 11:08) |
| `key-<id-without-C>` | Access level spec ("key-acme") | Blocked |
| `fleet-<id-without-C>` | Community PR fleetdm/fleet#46454 (suffix-first) | Denied (log 12:44, 99 min after the write) |
| `is_managed_device` and `is_compliant_device` | Access level spec | Both fail |
| `device.is_admin_approved_device` (no Fleet data) | Diagnostic | **Allowed, Drive opened** (log 11:00) |

## Idea not yet tested: approve/block instead of a client state
`device.is_admin_approved_device` is evaluated on this iPhone. Basic-management devices are approved by default and can be blocked;
the Cloud Identity API has `deviceUsers.block` and `deviceUsers.approve`. A sync could block every iOS device user that doesn't match a
Fleet host. Trade-off: a new unmanaged phone gets in until the next sync (about 5 minutes). Untested.
