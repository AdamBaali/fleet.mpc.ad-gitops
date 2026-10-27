# X-7: No package left for the reset

- **Started:** 2026-10-27T09:21:38Z
- **Objective:** Host 25 (c1 VM, bypass package kept in ProgramData from setup, nothing staged). Remove the kept package with a Fleet script, then wipe. Variant of the plan's X-7 (brownfield without staging): same end state, no package anywhere
- **Expected:** The reset comes back without fleetd and the host never checks in, which shows the package is what brings it back

## Steps and evidence
- `01-packages-before.txt`: `fleetctl run-script --host ED712DCB-E688-47A9-B129-E983573EE9EE --script-path payloads/local/list-packages.ps1`
- `02-remove-kept-package.txt`: `fleetctl run-script --host ED712DCB-E688-47A9-B129-E983573EE9EE --script-path payloads/local/remove-kept-ppkg.`
- `03-host-before.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -I tools/fleet-host-line.py`
- `04-wipe-command.txt`: `fleetctl mdm run-command --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --payload payloads/doWipePersistProvisio`
