# G-2b: the sync's API-only user limited to List hosts

- **Date:** 2026-10-09
- **Objective:** Give the sync token only what the script uses (`GET /api/v1/fleet/hosts` with `device_mapping=true`)
- **Expected:** List hosts works, everything else is refused, the sync still runs

## Steps and evidence
- `01` Before: API-only Observer, `api_endpoints: null` (full access for the role).
- `PATCH /api/v1/fleet/users/7` with `api_endpoints` is refused: 422 "This endpoint does not accept API endpoint values".
  The API-only route works: `PATCH /api/v1/fleet/users/api_only/7` with
  `{"api_endpoints": [{"method": "GET", "path": "/api/v1/fleet/hosts"}]}` (the "List hosts" entry from `GET /api/v1/fleet/rest_api`).
- After, with the sync token: `GET /hosts?device_mapping=true` 200; `GET /hosts/14`, `GET /config`, `GET /me` 403.
- The sync's dry run still works with the limited token (TESTING-LOG, E-2 rerun).

## Result: PASS

`fleetctl user create --api-only` can't set endpoints (finding 10); the REST API can, through the API-only route only.
