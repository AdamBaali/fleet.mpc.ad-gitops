# Handoff: reset with a provisioning package

## State (2026-10-26)
- Desk research done (NOTES.md D-1 to D-6).
- S-0 blocked: the `fleetctl` session on the Mac expired. Adam runs `fleetctl login`, then S-0 runs again.
- S-2 in PR 47 (branch `windows-ppkg-wipe-55003`): mock IdP metadata inline in `default.yml`,
  `fleets/windows-reset-lab.yml`, one secret line in `workflow.yml`, fleet row in the repo README.
- GitHub secret `FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET` exists but is empty. Adam sets it again from `private/.env`.
- S-1 done: mock IdP running in Docker (`ppkg-wipe-idp`, port 9080). Test login checked. Metadata inline in `default.yml`.

## Next steps
1. Adam: `fleetctl login`, or an API token in `private/.env` as `FLEET_API_TOKEN`.
2. Adam: create `private/.env` with the enroll secret and set the GitHub secret from it.
3. S-0 again. The PR dry run passes. Merge.
4. After the apply: check **Settings > Integrations > SSO > End users** and the new fleet. Other fleets unchanged.
5. S-3 to S-7, then E and W tests.

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
- Don't merge the S-2 PR before the enroll secret is set. A failed apply blocks every fleet.
