# Guide findings (customer Google guide)

## Added 2026-10-09 (live iPhone test, see TESTING-LOG.md)
| # | Step | Finding | Proposed edit |
| --- | --- | --- | --- |
| 16 | Step 3 script | Partner ID with the leading C and `customer=customers/<customer-ID>` make `clientStates.patch` return HTTP 400. Only `<id-without-C>-fleet` with `customers/my_customer` works | `PARTNER_ID="${GOOGLE_CUSTOMER_ID#C}-fleet"` and `customer=customers/my_customer` (done in `../../fleets/ios-google-lab/google-sync/`) |
| 17 | Step 3.4 workflow | `google-github-actions/auth@v2` with `access_token_subject` fails: HTTP 400 `invalid_request`. The action's README says a key needs `roles/iam.serviceAccountTokenCreator` on the service account (not tested) | Sign the JWT in the job (done in `../../.github/workflows/google-sync.yml`), or document the IAM role |
| 18 | Step 4 | **The access level is never satisfied by the Fleet state**: `device.vendors["fleet"]` and `device.vendors["<id-without-C>-fleet"]` both deny while Google shows the state as Managed/Compliant. A non-vendor condition passes on the same phone | **Resolved by 23:** the keyless `exists()` condition works. Named keys still fail; ask Google for the key |
| 19 | Step 4 | Assigning at the top-level OU applies to Admin Console and the admin | Say: select the test OU, Drive and Gmail only, Active, apply to desktop and mobile apps |
| 20 | Step 5 | After a sync, the app keeps showing the old block until a fresh sign-in | Say how the user gets in after enrolling (sign out and in, or wait) once C-1 passes |
| 21 | Step 4 | The condition is in the Admin console under Advanced; Google says edits take effect immediately. Reopen the level after saving: in testing the box was once seen empty | Add "reopen to check it saved" |
| 22 | Prereqs | Gmail needs MX records; a lab domain without mail can test with Drive | Note for testers |

## Added 2026-10-09 (evening)
| # | Step | Finding | Proposed edit |
| --- | --- | --- | --- |
| 7 | Step 3 and 4 | Google's reference for `clientStates` and its access level spec say the customer ID in the partner segment is "the string after the letter C (not including C)". The guide, the script (`PARTNER_ID="$GOOGLE_CUSTOMER_ID-fleet"`) and the CEL condition use it with the C. Not yet confirmed by a live call (E-14). | Use the ID without the leading C in the script and the condition. `proposed/guide-script-edits.diff` does it in the script |
| 8 | Step 3 script | If Fleet returns no hosts (wrong token scope, outage), the script marks every matched Google device UNMANAGED, blocking everyone. Duo's script refuses an empty list. | Add the guard in `proposed/guide-script-edits.diff` (tested on a mock Fleet: exit 1, nothing changed) |
| 9 | Step 3 workflow | Reuses the secret name `FLEET_API_TOKEN`, which GitOps repos already use for GitOps. | Use `GOOGLE_SYNC_FLEET_API_TOKEN` |
| 10 | Step 3 | `fleetctl user create --api-only` can't limit endpoints (prints "head to the Fleet UI"). | Say to set List hosts only in the UI |
| 11 | Step 2 | Missing delegation shows as `unauthorized_client` and can take a few minutes. | Name the error |
| 12 | Prereqs | First Google Cloud sign-in asks for a country and the Terms of Service. Client ID for delegation is the service account's Unique ID. | Add both notes |

## From the desk review (R-1, mock Fleet and Google)
| # | Finding | Proposed edit |
| --- | --- | --- |
| 13 | An old iPhone left in Google blocks the new one: one Fleet host plus two Google iPhones for the same user is ambiguous, so neither is marked managed. Common after a phone upgrade. | Troubleshooting: delete the old device in Google Admin |
| 14 | Any email source counts, including an admin-set custom email. | Superseded by 31: use the IdP email only by default |
| 15 | A failed Google write stops the run (exit 22). Earlier writes are kept. The Action shows red, the next run carries on. | Say so |

## Added 2026-10-09 (C-2 and E-2)
| # | Step | Finding | Proposed edit |
| --- | --- | --- | --- |
| 23 | Step 4 | **Working condition:** `device.vendors.exists(k, device.vendors[k].is_managed_device == true)`. The managed iPhone opens Drive (C-1e), a user without a Fleet state is blocked on the same phone (C-2). Caveat: it accepts any third-party state that says managed | Use this condition. Add: "If another device partner also writes states, this condition trusts it too" |
| 24 | Step 4 | Google rejects `contains` and list literals inside `exists()` ("not allowed in comprehensions"), so the condition can't be narrowed to Fleet's key | Ask Google for the key of a customer-owned state; narrow the condition once known |
| 25 | Step 3 workflow | The script prints `<Google device> (<end user email>/iphone): A -> B` on each change. In a public repository, or with strict log rules, that exposes emails and device IDs | Mask them in the workflow (`sed` in `../../.github/workflows/google-sync.yml`), or tell admins to use a private repository |
| 26 | Step 3 script | The empty-Fleet guard (finding 8) also stops the script when the **last** managed iPhone leaves Fleet, so that phone stays MANAGED in Google. Fine with many phones; a pilot with one phone sees "removed from Fleet, still allowed" | Say so, or stop only when Fleet returns no hosts at all |
| 27 | Step 3 script | Matching is by email and device type only. If a user's Fleet iPhone isn't signed in to Google but a personal iPhone is, both counts are 1 and the **personal** iPhone is marked MANAGED. Google records the model, so a model check would narrow it; the OS version can't be used (C-2: the same phone reported iOS 18.7 and 26.6.1) | Document the limit. Optional: compare the model (Fleet `iPhone16,2` = Google "iPhone 15 Pro Max") |
| 28 | Troubleshooting | A second Google account on the same iPhone creates a second device record (same "Device ID" in the console). Each account has its own client state; the script handles them per account | One line in Troubleshooting so admins aren't surprised by two entries |
| 29 | Step 3 script | The client state has `assetTags`, and the console shows them under Third-party services. Writing Fleet's serial number there shows which Fleet host Google trusts (Google has no serial for these iPhones) | Optional: the lab script writes the serial (`../../fleets/ios-google-lab/google-sync/`) |
| 30 | Step 3 workflow | GitHub runs schedules best effort: a scheduled run in the lab never started. The script now prints a one-line summary on every run, so missing or failing runs are easy to spot | Say schedules can be late or skipped; check the Actions history |
| 31 | Prereqs and Step 3 script | The script used every email Fleet has for the host. For iPhones and iPads Fleet reports two sources: `mdm_idp_accounts` (the IdP account from end user authentication at enrollment, or an IdP username an admin set) and `custom` (set through the API or UI). Matching on the IdP email only means the Google account must be the one the user enrolled with | Prerequisite: turn on end user authentication for the iPhone fleet (`setup_experience.enable_end_user_authentication`, applies to iOS/iPadOS). Script: `EMAIL_SOURCES` (default `mdm_idp_accounts`; the lab adds `custom` because it has no IdP) |
| 32 | Step 3 script | The script counts every MDM status that starts with "On", including `On (personal)` (BYOD). A personally enrolled iPhone with the user's IdP email is marked MANAGED and gets access. Fine if BYOD should get in; not if only company-owned phones should | Say so. Optional setting to count `On (automatic)` (ADE) only, or a fleet/label filter |
