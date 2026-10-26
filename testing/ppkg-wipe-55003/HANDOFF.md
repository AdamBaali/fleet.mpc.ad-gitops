# Handoff: reset with a provisioning package

## State (2026-10-26)
- Desk research done (NOTES.md D-1 to D-6).
- S-0 PASS: Fleet 4.93.0, Premium, Windows MDM on. `allow_orbit_end_user_auth_bypass` is unset on Render, so `true`
  (the default). Left unset on purpose: it is what customers run.
- S-2 PASS: PR 47 merged and applied. Windows Reset Lab is fleet 10, the only fleet with end user authentication on.
- `fleetctl` on the Mac uses an API token (`~/.fleet/config`). The enroll secret is in `private/.env` and in GitHub.
- S-1 done: mock IdP running in Docker (`ppkg-wipe-idp`, port 9080). Test login checked. Metadata inline in `default.yml`.

## Next steps
1. Update `fleetctl` to 4.93.0 to match the server before building MSIs.
2. S-3 to S-7, then E and W tests.

## Running services (keep them on)
- `ppkg-wipe-idp` (Docker, port 9080 on all interfaces). Check: `docker ps --filter name=ppkg-wipe-idp`. Stop: `docker compose -f idp/docker-compose.yml down`.

## Teardown
- UTM: `ppkg-golden-oobe`, every clone, the builder VM if made for this project, the USB images.
- Local files: MSIs, WCD project folders, `.ppkg` files (they hold the enroll secret).
- Fleet: hosts in "Windows Reset Lab", then the fleet file. Rotate its enroll secret if a package left the Mac.
- Fleet: remove `mdm.end_user_authentication` from `default.yml` unless another lab uses it.
- GitHub: secret `FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET` and its `workflow.yml` line.
- Mock IdP: see IDP_SETUP.md "Teardown".

## Rules learned
- Delete the host in Fleet before a reset when the test needs a first-time enrollment (NOTES.md D-1).
- Don't merge a PR that adds a secret variable before the secret is set. A failed apply blocks every fleet.
- `fleetctl get fleets` skips fleets whose name has an emoji. Use `fleetctl api /api/v1/fleet/fleets`.
