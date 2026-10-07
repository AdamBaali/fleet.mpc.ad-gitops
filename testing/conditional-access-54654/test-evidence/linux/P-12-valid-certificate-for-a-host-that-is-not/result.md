# P-12: Valid certificate for a host that is not in Fleet is denied cleanly

- **Started:** 2026-10-07T18:17:04Z
- **Objective:** A certificate issued by the lab CA for a UUID Fleet has never seen is denied with a clear message, not a server error.
- **Expected:** error=access_denied and 'Host is not in Fleet or is failing a critical policy'.

## Steps and evidence
- `01-issued-certificate.txt`: `echo 'Certificate issued by the lab CA for a UUID Fleet has never seen (CN below); private key not saved in th`
- `02-fleet-has-no-such-host.txt`: `echo "Fleet lookup for 0935f82c-9fc2-41d2-b6f7-69066f75b507:"; fleetctl api '/hosts/identifier/0935f82c-9fc2-4`
- `03-unknown-host-signin.txt` (VM): `bash /tmp/signin.sh /tmp/ghost.crt /tmp/ghost.key`
- `04-cleanup.txt` (VM): `unlink /tmp/ghost.key; unlink /tmp/ghost.crt; echo removed`

## Result: **PASS**

A valid lab-CA certificate for a UUID that Fleet does not have gets a clean access_denied redirect (not a server error page). PingFederate logs a warning for the Fleet 404.

_Finished 2026-10-07T18:17:09Z_
