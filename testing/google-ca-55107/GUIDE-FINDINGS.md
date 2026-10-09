# Guide findings (customer Google guide)

## Added 2026-10-09 (live iPhone test, see TESTING-LOG.md)
| # | Step | Finding | Proposed edit |
| --- | --- | --- | --- |
| 16 | Step 3 script | Partner ID with the leading C and `customer=customers/<customer-ID>` make `clientStates.patch` return HTTP 400. Only `<id-without-C>-fleet` with `customers/my_customer` works | `PARTNER_ID="${GOOGLE_CUSTOMER_ID#C}-fleet"` and `customer=customers/my_customer` (done in `../../fleets/ios-google-lab/google-sync/`) |
| 17 | Step 3.4 workflow | `google-github-actions/auth@v2` with `access_token_subject` fails: HTTP 400 `invalid_request`. The action's README says a key needs `roles/iam.serviceAccountTokenCreator` on the service account (not tested) | Sign the JWT in the job (done in `../../.github/workflows/google-sync.yml`), or document the IAM role |
| 18 | Step 4 | **The access level is never satisfied by the Fleet state**: `device.vendors["fleet"]` and `device.vendors["<id-without-C>-fleet"]` both deny while Google shows the state as Managed/Compliant. A non-vendor condition passes on the same phone | Blocker. Don't publish until Google confirms the key or support for customer-written states on iOS |
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
| 14 | Any email source counts, including an admin-set custom email. | One line in the prerequisites |
| 15 | A failed Google write stops the run (exit 22). Earlier writes are kept. The Action shows red, the next run carries on. | Say so |
