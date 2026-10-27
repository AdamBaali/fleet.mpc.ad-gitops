# X-3: Enroll secret rotated after the package was built

- **Started:** 2026-10-27T08:12:52Z
- **Objective:** Host 25 (c1 VM, bypass package, fresh from X-2). Replace fleet 10 enroll secret through the API (a stand-in for a GitOps rotation), wipe, then restore the GitOps secret
- **Expected:** fleetd comes back but cannot enroll until the secret in the package is valid again

## Steps and evidence
- `01-secret-before.txt`: `python3 -I tools/fleet-secret.py show`
- `02-rotate-secret.txt`: `python3 -I tools/fleet-secret.py rotate`
- `03-wipe-command.txt`: `fleetctl mdm run-command --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --payload payloads/doWipePersistProvisio`
- `04-orbit-log-enroll-fails.png` (VM screen, Shift+F10 at the region screen)

Reset done and the region screen was up at about 08:30 (watch). For 26 minutes after that Fleet showed host 25 offline with the old enrollment. At 08:56 the orbit log (04) shows fleetd running and retrying: "orbit enroll attempt failed ... enroll request: unauthenticated, or invalid token", and osquery "Failed enrollment request". Restoring the GitOps secret next.
- `05-restore-secret.txt`: `python3 -I tools/fleet-secret.py restore`
- `06-host-25-after.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -c 'import sys,json; h=json.load(sys.stdin)["host"];`
- `07-live-query-after.txt`: `fleetctl query --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --exit --timeout 90s --query "$(cat queries/after-`
- `08-secret-after.txt`: `python3 -I tools/fleet-secret.py show`
- `09-host-25-mdm-later.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -I tools/fleet-host-line.py`

After the GitOps secret was restored at 08:58:06, fleetd enrolled at 08:58:27 (21 s, fleetd retries on its own): same host 25, fleet 10, built-in users only, kept package (host-25-after, live-query-after). So a rotation strands every reset host with an old package at the setup screen until the package is rebuilt or the old secret is valid again; Fleet shows nothing about it (host offline, old enrollment date). Fleet 10 is back to the GitOps secret (secret-after).

## Result: PASS

With the enroll secret rotated, fleetd comes back after the reset but can't enroll ("unauthenticated, or invalid token"); it enrolls 21 s after the old secret is valid again

_Finished 2026-10-27T09:02:07Z_
