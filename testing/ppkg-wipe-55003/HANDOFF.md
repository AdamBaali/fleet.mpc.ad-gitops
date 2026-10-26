# Handoff: reset with a provisioning package

## State (2026-10-26)
- Desk research done (NOTES.md D-1 to D-6).
- S-0 blocked: the `fleetctl` session on the Mac expired. Adam runs `fleetctl login`, then S-0 runs again.
- S-2 files written on branch `windows-ppkg-wipe-55003`, not committed: IdP block in `default.yml`,
  `fleets/windows-reset-lab.yml`, two secret lines in `workflow.yml`, fleet row in the repo README.
- The two GitHub secrets don't exist yet. Adam sets them (writing secrets needs Adam).
- Okta org and test users: Adam is creating them.

## Next steps
1. Adam: Okta org, SAML app, two test users ([IDP_SETUP.md](IDP_SETUP.md)).
2. Adam: `fleetctl login`.
3. Adam: set the secrets. The enroll secret also goes in `private/.env` (git ignores it) so the MSI build can read it.
4. S-0 again. Then `fleetctl gitops --dry-run` with both values in the environment. Then commit, PR, merge.
5. After the apply: check **Settings > Integrations > SSO > End users** and the new fleet. Other fleets unchanged.
6. S-3 to S-7, then E and W tests.

## Running services (keep them on)
None yet.

## Teardown
- UTM: `ppkg-golden-oobe`, every clone, the builder VM if made for this project, the USB images.
- Local files: MSIs, WCD project folders, `.ppkg` files (they hold the enroll secret).
- Fleet: hosts in "Windows Reset Lab", then the fleet file. Rotate its enroll secret if a package left the Mac.
- Fleet: remove `mdm.end_user_authentication` from `default.yml` unless another lab uses it.
- GitHub: secrets `FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET` and `FLEET_EUA_METADATA_URL`, and their `workflow.yml` lines.
- Okta: see IDP_SETUP.md "Teardown".

## Rules learned
- Delete the host in Fleet before a reset when the test needs a first-time enrollment (NOTES.md D-1).
- Don't merge the S-2 PR before both secrets exist. GitOps fails on an unset variable, and that blocks every fleet.
