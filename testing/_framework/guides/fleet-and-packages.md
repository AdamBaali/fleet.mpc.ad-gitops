# Fleet and packages

`private/fleet.env` (git ignores it):
```
FLEET_URL=https://fleet.mpc.ad
FLEET_API_TOKEN=...
```
Use an API-only user with the lowest role the test needs. `ev_cmd` masks values from `SECRETS_ENV` whose names contain
KEY, SECRET, TOKEN, PASSWORD, CHALLENGE, or ENROLL. Add `LAB_DEVICE_SECRET_1=<serial>` to mask a serial.

```bash
bin/fleet-api.sh version | host <serial> | wait-host <id> | activity <host id>    # read-only
bin/clock-check.sh                                                                  # before timed tests
```

Packages: `fleetctl package --type=msi|pkg|deb|rpm --fleet-url "$FLEET_URL" --enroll-secret "$SECRET" --fleet-desktop
--enable-scripts`. The secret is inside the package, so build one per fleet, keep it out of git, and read the secret from
`.env` or the API. Check the active `fleetctl` context first.

Between runs: `fleetctl mdm wipe --host <serial>`, then delete the host so the next run is a new host. Remove throwaway
secrets, tokens, users, and VMs at the end.
