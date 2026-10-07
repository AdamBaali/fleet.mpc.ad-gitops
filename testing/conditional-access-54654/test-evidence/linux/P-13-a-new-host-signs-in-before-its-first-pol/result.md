# P-13: A new host signs in before its first policy run

- **Started:** 2026-10-07T18:42:14Z
- **Objective:** A host that has just enrolled in Fleet has no policy results yet. Unrun policies are not counted as failing, so sign-in succeeds (the guide may need to say so).
- **Expected:** Authorization code returned while the host's policy responses are still empty.

## Steps and evidence
- `01-host-before.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '{id:.host.id, uuid:.ho`
- `02-delete-host.txt`: `T0=$(date +%s); fleetctl api -X DELETE /hosts/9 2>&1 | grep -v -E 'Warning|Version|Client|Server'; echo "host `
- `03-wait-for-reenrollment.txt`: `t0=$(date +%s); for i in $(seq 1 40); do r=$(fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517`
- `04-host-just-enrolled.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '{id:.host.id, status:.`
- `05-signin-right-away.txt` (VM): `bash /tmp/signin.sh cert`
- `06-health-right-away.txt`: `HID=$(fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq -r .host.id); cur`

## Result: **PASS**

Deleting the host made fleetd re-enroll it within 8 seconds (new host id 13, policy responses empty). A sign-in right away returned an authorization code and failing_critical_policies_count was 0, so unrun policies do not block. A brand-new host is trusted until its first policy run.

_Finished 2026-10-07T18:43:04Z_
