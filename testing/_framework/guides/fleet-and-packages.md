# Fleet, packages, and secrets

## Environment file

Each project keeps `private/fleet.env` (git ignores `private/`):

```
FLEET_URL=https://fleet.mpc.ad
FLEET_API_TOKEN=...
```

Use an API-only user with the lowest role the test needs (the Google test used an observer limited to List hosts).
`bin/ev.sh` masks any value from `SECRETS_ENV` whose name contains KEY, SECRET, TOKEN, PASSWORD, CHALLENGE, or ENROLL.
Add `LAB_DEVICE_SECRET_1=<serial>` lines to mask device serials too.

```bash
export SECRETS_ENV=$PWD/private/fleet.env
bin/fleet-api.sh version                # also: host <serial>, wait-host <id>, activity <host id>
bin/clock-check.sh                      # before any timed test
```

## Enroll secrets and packages

- Each lab fleet has its own enroll secret, set in the GitOps repo as `$FLEET_<NAME>_ENROLL_SECRET` and as a GitHub
  repository secret. The fleet file never holds the value.
- `fleetctl package` bakes the secret into the package. Build one per fleet, keep the output out of git, and read the
  secret from `.env` or the Fleet API at build time. Pipe build output through `grep -v -i secret`.
- Check the active `fleetctl` context first. Use `--config` for a lab-only config file.
- `fleetctl api -F` sends flat fields only. For nested JSON, POST with curl or `testing/ppkg-wipe-55003/tools/fleet-post.py`.

## Between runs

- Wipe with `fleetctl mdm wipe --host <serial>`, wait for Fleet to show it, then delete the host so the next run enrolls as
  a new host.
- Rotate or delete throwaway enroll secrets, API tokens, users, and tunnels. List them in `HANDOFF.md` under Teardown.
- A push to `main` applies to the lab Fleet. Fleet changes go through a pull request (`.github/workflows/workflow.yml`
  skips pushes that only touch `testing/`).
