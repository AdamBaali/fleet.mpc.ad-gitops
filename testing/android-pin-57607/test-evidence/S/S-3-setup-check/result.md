# S-3: setup check

- **Started:** 2026-11-05T09:04:36Z
- **Objective:** API access from private/fleet.env works
- **Expected:** version shown

## Steps and evidence
- `01-api.txt`: `tools/setup-check.sh version`

- Token: an admin session token from fleetctl, not an API-only user. It expires with that session.

## Result: PASS

API works with the token in private/fleet.env; Fleet 4.94.0.

_Finished 2026-11-05T09:04:37Z_
