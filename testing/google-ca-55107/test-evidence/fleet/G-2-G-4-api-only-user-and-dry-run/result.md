# G-2/G-4: API-only Fleet user and sync script dry run

- **Date:** 2026-10-09
- **Objective:** Follow guide Step 1 and run the script with DRY_RUN
- **Expected:** Observer API-only user; dry run exits 0

## Steps and evidence
- `01-fleet-user-role.txt`: created with `fleetctl user create --api-only --global-role observer`. `GET /me` shows api_only true, role observer; `GET /hosts` returns 200.
- `02-dry-run.txt`: the guide's script with `DRY_RUN=true`: exit 0, no output. Expected: Google has 0 iOS devices yet.

## Result: PASS

Findings: `fleetctl user create` cannot limit the user to List hosts only (it says to use the Fleet UI), so `GET /me` also works for this user. A first token pasted in chat belonged to a global admin, not this user: use the API-only user.
