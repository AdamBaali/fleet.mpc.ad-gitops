# K-7: what Fleet shows after the user slot is removed

- **Date:** 2026-10-15
- **Objective:** Does Fleet notice that the end user's key is gone?
- **Expected:** No: Fleet verifies the escrow slot's salt, not the user's slot.

## Steps and evidence
- `01-fleet-status.txt`: after removing slot 0 and a refetch (3 minutes), the host is still **verified**, the escrowed key is still stored and available. No banner or action required.
- `02-screenshot-fleet-still-verified.png`: window screenshot: Fleet still verified.

## Result: PASS

Doc point: removing the end user's key doesn't change anything in Fleet. Fleet can't tell the end user is locked out.
