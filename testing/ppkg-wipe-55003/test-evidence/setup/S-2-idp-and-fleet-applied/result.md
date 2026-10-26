# S-2: IdP and fleet applied

- **Started:** 2026-10-26T15:58:08Z
- **Objective:** PR 47 applied: IdP in org settings, Windows Reset Lab with end user authentication, other fleets unchanged
- **Expected:** IdP name and entity ID set with inline metadata; only fleet 10 requires end user authentication

## Steps and evidence
- `01-idp-config.txt`: `fleetctl api /api/v1/fleet/config 2>/dev/null | python3 -c 'import json,sys; e=json.load(sys.stdin)["mdm"]["en`
- `02-fleets-eua.txt`: `for id in $(fleetctl api /api/v1/fleet/fleets 2>/dev/null | python3 -c 'import json,sys; [print(t["id"]) for t`
- `03-global-eua.txt`: `fleetctl api /api/v1/fleet/config 2>/dev/null | python3 -c 'import json,sys; m=json.load(sys.stdin)["mdm"]; pr`

## Result: PASS

IdP 'Lab IdP' with entity ID fleet-mpc-ad-end-users and inline metadata pointing at the mock IdP. Only fleet 10 (Windows Reset Lab) requires end user authentication; the other seven fleets and hosts in no fleet don't.

_Finished 2026-10-26T15:58:29Z_
