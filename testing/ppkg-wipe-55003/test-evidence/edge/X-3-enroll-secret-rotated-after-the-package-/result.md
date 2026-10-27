# X-3: Enroll secret rotated after the package was built

- **Started:** 2026-10-27T08:12:52Z
- **Objective:** Host 25 (c1 VM, bypass package, fresh from X-2). Replace fleet 10 enroll secret through the API (a stand-in for a GitOps rotation), wipe, then restore the GitOps secret
- **Expected:** fleetd comes back but cannot enroll until the secret in the package is valid again

## Steps and evidence
- `01-secret-before.txt`: `python3 -I tools/fleet-secret.py show`
- `02-rotate-secret.txt`: `python3 -I tools/fleet-secret.py rotate`
- `03-wipe-command.txt`: `fleetctl mdm run-command --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --payload payloads/doWipePersistProvisio`
