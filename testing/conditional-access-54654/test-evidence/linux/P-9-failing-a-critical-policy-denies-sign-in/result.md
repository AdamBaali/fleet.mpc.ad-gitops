# P-9: Failing a critical policy denies sign-in

- **Started:** 2026-10-07T18:11:05Z
- **Objective:** When a critical policy fails and the host refetches, sign-in is denied with a clear message.
- **Expected:** Sign-in redirects with error=access_denied and 'Host is not in Fleet or is failing a critical policy'.

## Steps and evidence
- `01-before.txt` (VM): `bash /tmp/signin.sh cert`
- `02-flip-to-failing.txt`: `bash evidence/flip.sh fail`
- `03-fleet-policy-state.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '[.host.policies[]|{nam`
- `04-signin-denied.txt` (VM): `bash /tmp/signin.sh cert`

## Result: **PASS**

Creating the flag file and selecting Refetch: Fleet showed failing_critical_policies_count 1 after 160 seconds. Sign-in was then denied with error=access_denied and the message Host is not in Fleet or is failing a critical policy.

_Finished 2026-10-07T18:16:33Z_

### Browser re-run with screenshots (2026-10-07)
- `05-browser-flip-to-failing.txt`: `bash evidence/flip.sh fail`
- `06-browser-launch.txt` (VM): `bash /tmp/br.sh chromium`
- `07-browser-signin-denied.png` (VM screenshot)
- `08-browser-callback-log.txt` (VM): `bash /tmp/killbr.sh`
- Browser screenshots added 2026-10-07 (Chromium in the VM; one-time sign-in code masked).
