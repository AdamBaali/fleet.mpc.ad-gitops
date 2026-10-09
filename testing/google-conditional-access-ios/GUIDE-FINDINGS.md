# Guide findings (customer-antonella Google guide)

## Added 2026-10-09 (evening)
| # | Step | Finding | Proposed edit |
| --- | --- | --- | --- |
| 7 | Step 3 and 4 | Google's reference for `clientStates` and its access level spec say the customer ID in the partner segment is "the string after the letter C (not including C)". The guide, the script (`PARTNER_ID="$GOOGLE_CUSTOMER_ID-fleet"`) and the CEL condition use it with the C. Not yet confirmed by a live call (E-14). | Use the ID without the leading C in the script and the condition. `proposed/guide-script-edits.diff` does it in the script |
| 8 | Step 3 script | If Fleet returns no hosts (wrong token scope, outage), the script marks every matched Google device UNMANAGED, blocking everyone. Duo's script refuses an empty list. | Add the guard in `proposed/guide-script-edits.diff` (tested on a mock Fleet: exit 1, nothing changed) |
| 9 | Step 3 workflow | Reuses the secret name `FLEET_API_TOKEN`, which GitOps repos already use for GitOps. | Use `GOOGLE_SYNC_FLEET_API_TOKEN` |
| 10 | Step 3 | `fleetctl user create --api-only` can't limit endpoints (prints "head to the Fleet UI"). | Say to set List hosts only in the UI |
| 11 | Step 2 | Missing delegation shows as `unauthorized_client` and can take a few minutes. | Name the error |
| 12 | Prereqs | First Google Cloud sign-in asks for a country and the Terms of Service. Client ID for delegation is the service account's Unique ID. | Add both notes |
