# C-1b: the sync script with both fixes

- **Date:** 2026-10-09
- **Objective:** Prove the corrected script (`fleets/ios-google-lab/google-sync/sync-fleet-hosts-to-google.sh`) writes the state
- **Expected:** `UNMANAGED -> MANAGED`, read back MANAGED, second run does nothing

## Steps and evidence
- State set to UNMANAGED by hand first, so the script has something to change.
- `01`: DRY_RUN and LIVE both print `(<managed test user>/iphone): UNMANAGED -> MANAGED`, exit 0. Read back: `MANAGED`, `COMPLIANT`, `customId` = the Fleet host ID. Second run: no output, exit 0 (E-11 idempotent).
- Admin console > device > Third-party services shows **"fleet (custom)"**, Managed, Compliant, ID = the Fleet host ID. The console names the vendor by the suffix only.

## Result: PASS
