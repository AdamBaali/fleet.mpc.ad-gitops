# S-0: Record the lab

**Objective:** Record Fleet version, the end user auth bypass setting, the IdP, and which fleets require end user auth  
**Expected:** Fleet 4.93.x, bypass true, IdP set, only Windows Reset Lab requires end user auth  
**Run:** 2026-10-26T15:57:24Z to 2026-10-26T15:58:08Z

## Evidence

- `01-fleet-version.txt`: `fleetctl api /api/v1/fleet/version 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.`
- `02-server-config.txt`: `fleetctl get config --include-server-config --yaml 2>/dev/null | grep -n -E 'allow_orbit_end_user_auth_bypass|`
- `03-fleets-eua.txt`: `fleetctl api /api/v1/fleet/fleets 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(t[`
- `04-bypass-not-in-api.txt`: `fleetctl get config --include-server-config --yaml 2>/dev/null | grep -c -i allow_orbit_end_user_auth_bypass; `
- `05-code-diff-4930-4932.txt`: `cd ../fleet && git diff --stat fleet-v4.93.0 fleet-v4.93.2 -- server/service/orbit.go server/datastore/mysql/h`

## What happened

Fleet 4.93.0. Premium. Windows MDM on, automatic Windows MDM turn-on (enable_turn_on_windows_mdm_manually false). Fleet
10 is the only fleet with end user authentication on (checked per fleet in S-2). The live
allow_orbit_end_user_auth_bypass isn't exposed by the API; the code default is true and the Render environment decides.
E-1b shows it in practice. The 4.93.0 to 4.93.2 changes in the cited files don't touch enrollment, so NOTES.md D-1 to D-3
hold at 4.93.0.

## Result: PASS

Version, license, MDM, and fleets recorded. The bypass setting isn't in the API. The lab owner confirmed
FLEET_MDM_ALLOW_ORBIT_END_USER_AUTH_BYPASS isn't set on Render (2026-10-26), so it is the default, true. Left unset on
purpose: it is what customers run.
