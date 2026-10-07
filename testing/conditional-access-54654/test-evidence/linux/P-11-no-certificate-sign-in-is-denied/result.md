# P-11: No certificate: sign-in is denied

- **Started:** 2026-10-07T18:17:04Z
- **Objective:** A client that presents no certificate cannot sign in.
- **Expected:** error=access_denied and 'Authentication failed'.

## Steps and evidence
- `01-no-cert-signin.txt` (VM): `bash /tmp/signin.sh nocert`

## Result: **PASS**

Without a client certificate PingFederate redirects with error=access_denied and the message Authentication failed.

_Finished 2026-10-07T18:17:04Z_
