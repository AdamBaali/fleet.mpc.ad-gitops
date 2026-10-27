# A-3: Fleet wipe API rejects the reprovision wipe types

**Objective:** POST /api/v1/fleet/hosts/25/wipe with windows.wipe_type set to each reprovision type, on a lab host that is offline and would be wiped anyway  
**Expected:** Rejected; only `doWipe` and `doWipeProtected` are accepted today  
**Run:** 2026-10-27T07:08:50Z to 2026-10-27T07:09:19Z

## Evidence

- `01-post-doWipePersistProvisionedData.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/25/wipe '{"windows":{"wipe_type":"'doWipePersistProvisioned`
- `02-post-doWipeCloudPersistProvisionedData.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/25/wipe '{"windows":{"wipe_type":"'doWipeCloudPersistProvis`
- `03-control-valid-type-unknown-host.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/999999/wipe '{"windows":{"wipe_type":"doWipeProtected"}}'`
- `04-host-25-no-pending-wipe.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -c 'import sys,json; m=json.load(sys.stdin)["host"][`

## What happened

Both reprovision types return 400 "failed to unmarshal request body". The body shape is right: the control with
`doWipeProtected` and an unknown host gets past parsing to 404, so nothing was sent to a host. At fleet-v4.93.0,
`MDMWindowsWipeType`.UnmarshalJSON (server/fleet/windows_mdm.go:739) knows only `doWipe` and `doWipeProtected` and
returns "invalid WipeType", which the API reports as a generic unmarshal error. Host 25 shows no pending action
afterwards. tools/fleet-post.py sends nested JSON, which fleetctl api -F cannot.

## Result: PASS

The wipe API rejects `doWipePersistProvisionedData` and `doWipeCloudPersistProvisionedData` with a generic 400 ("failed
to unmarshal request body"); the parser at v4.93.0 knows only `doWipe` and `doWipeProtected`.
