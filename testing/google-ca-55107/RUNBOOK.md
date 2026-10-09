# Runbook: run the loop again

The E-2b loop: managed, guard, blocked, back. Each step changes Fleet, syncs, and checks the phone. Helpers are in `scripts/`
(they read the lab's `.env` and service account key, which aren't in this repo).

| Step | Fleet change | Sync | Expected on the phone (Drive as the managed user) |
|---|---|---|---|
| R1 | `scripts/fleet-email.sh idp managed` (IdP username set by API) | Run the workflow by hand with **dry_run** off | Opens. Admin console > device > **Third-party services**: fleet (custom), Managed, serial under **Asset tags** |
| R2 | `scripts/fleet-email.sh idp-delete` (the only phone loses its email) | Same | Run fails with "No email" and the guard. Nothing changes |
| R3 | `scripts/fleet-email.sh idp dummy` | Same | "Your organisation isn't allowing access" within seconds, no sign-in |
| R4 | `scripts/fleet-email.sh idp managed` | Same | "Please sign in again". Close it and reopen Drive: opens |

Check the state at any point with `scripts/state.sh get` (read only). To capture the phone, use iPhone Mirroring with the phone
locked, and `scripts/live-shots.sh <dir>` (window-only frames every 4 seconds).

Manual sync from the command line:
```bash
gh workflow run google-sync.yml -R AdamBaali/fleet.mpc.ad-gitops -f dry_run=false
```
