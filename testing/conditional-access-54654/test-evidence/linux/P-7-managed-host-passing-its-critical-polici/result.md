# P-7: Managed host passing its critical policies can sign in

- **Started:** 2026-10-07T18:10:37Z
- **Objective:** A Fleet host with passing critical policies signs in to PingFederate with its device certificate.
- **Expected:** Authorization code returned.

## Steps and evidence
- `01-fleet-policy-state.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '{host_id:.host.id, pol`
- `02-fleet-health.txt`: `HID=$(fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq -r .host.id); cur`
- `03-signin.txt` (VM): `bash /tmp/signin.sh cert`

## Result: **PASS**

Critical policy passing (failing_critical_policies_count 0); the VM signed in with its certificate and PingFederate returned an authorization code.

_Finished 2026-10-07T18:10:45Z_
