# P-10: Fixing the critical policy restores sign-in

- **Started:** 2026-10-07T18:13:54Z
- **Objective:** After the policy passes again and the host refetches, the next sign-in works.
- **Expected:** Fleet's count returns to 0 within about a minute and sign-in returns a code.

## Steps and evidence
- `01-flip-to-passing.txt`: `bash evidence/flip.sh pass`
- `02-fleet-policy-state.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '[.host.policies[]|{nam`
- `03-signin-restored.txt` (VM): `bash /tmp/signin.sh cert`

## Result: **PASS**

Removing the flag file and selecting Refetch: Fleet showed failing_critical_policies_count 0 after 146 seconds. The next sign-in returned an authorization code.

_Finished 2026-10-07T18:16:33Z_
