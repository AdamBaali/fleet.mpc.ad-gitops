# P-1: Which roles can send the wipe and run the staging script

- **Started:** 2026-10-27T08:10:01Z
- **Objective:** Read Fleet's authorization rules at fleet-v4.93.0 for the custom MDM command (fleetctl mdm run-command), the built-in wipe, and scripts
- **Expected:** Recorded per role

## Steps and evidence
- `01-rego-mdm-command-write.txt`: `git -C <fleet repo> show fleet-v4.93.0:server/authz/policy.rego | sed -n 1056,1069p`
- `02-run-mdm-command-authz.txt`: `git -C <fleet repo> show fleet-v4.93.0:server/service/mdm.go | sed -n 519,521p`
- `03-built-in-wipe-authz.txt`: `git -C <fleet repo> show fleet-v4.93.0:ee/server/service/hosts.go | sed -n 279,286p`
- `04-rego-script-write.txt`: `git -C <fleet repo> show fleet-v4.93.0:server/authz/policy.rego | sed -n 1298,1322p`

| Role (global, or fleet-level for hosts in that fleet) | Send the reprovision wipe (custom MDM command) | Built-in Wipe | Run the staging script |
|---|---|---|---|
| Admin | Yes | Yes | Yes |
| Maintainer | Yes | Yes | Yes |
| GitOps | Yes | Yes | No |
| Technician | No | No | Yes |
| Observer, Observer+ | No (can read results) | No | No (can read results) |

The custom command and the built-in wipe use the same check (mdm_command write), so moving the reprovision wipe into the Wipe action keeps today's permissions. A technician can stage the package but not wipe. From code at the release tag; not run with an API-only user per role.

## Result: PASS

From code at fleet-v4.93.0: admins, maintainers and GitOps users can send the wipe (same check as the built-in Wipe); admins, maintainers and technicians can run the staging script

_Finished 2026-10-27T08:10:01Z_
