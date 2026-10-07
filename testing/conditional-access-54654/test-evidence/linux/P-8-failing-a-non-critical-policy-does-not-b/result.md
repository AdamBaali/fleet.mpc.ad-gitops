# P-8: Failing a non-critical policy does not block sign-in

- **Started:** 2026-10-07T18:10:45Z
- **Objective:** A host failing only a non-critical policy can still sign in.
- **Expected:** Authorization code returned.

## Steps and evidence
- `01-fleet-policy-state.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '{host_id:.host.id, pol`
- `02-signin.txt` (VM): `bash /tmp/signin.sh cert`

## Result: **PASS**

The non-critical policy 'CA test - always fails (non-critical)' is failing on the host and sign-in still succeeded.

_Finished 2026-10-07T18:10:50Z_

### Browser screenshot added 2026-10-08 (Chromium in the VM; one-time sign-in code masked)
- `03-browser-policy-state.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '[.host.policies[]|{nam`
- `04-browser-launch.txt` (VM): `bash /tmp/br.sh chromium`
- `05-browser-signin-ok.png` (VM screenshot)
- `06-browser-callback-log.txt` (VM): `bash /tmp/killbr.sh`
