# X-7: No package left for the reset

- **Started:** 2026-10-27T09:21:38Z
- **Objective:** Host 25 (c1 VM, bypass package kept in ProgramData from setup, nothing staged). Remove the kept package with a Fleet script, then wipe. Variant of the plan's X-7 (brownfield without staging): same end state, no package anywhere
- **Expected:** The reset comes back without fleetd and the host never checks in, which shows the package is what brings it back

## Steps and evidence
- `01-packages-before.txt`: `fleetctl run-script --host ED712DCB-E688-47A9-B129-E983573EE9EE --script-path payloads/local/list-packages.ps1`
- `02-remove-kept-package.txt`: `fleetctl run-script --host ED712DCB-E688-47A9-B129-E983573EE9EE --script-path payloads/local/remove-kept-ppkg.`
- `03-host-before.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -I tools/fleet-host-line.py`
- `04-wipe-command.txt`: `fleetctl mdm run-command --hosts ED712DCB-E688-47A9-B129-E983573EE9EE --payload payloads/doWipePersistProvisio`
- `06-no-fleetd-at-region-screen.png` (VM screen, Shift+F10 at the region screen, 09:39 UTC)
- `06-host-25-still-offline.txt`: `fleetctl api /api/v1/fleet/hosts/25 2>/dev/null | python3 -I tools/fleet-host-line.py`

Timeline (UTC): kept package removed by a Fleet script 09:22:00 (0 packages left), wipe sent 09:22:28, host offline 09:24:37, region screen at about 09:35 (watch). At 09:39 Shift+F10 shows no osquery, orbit or Fleet service, no Orbit folder under Program Files, 0 packages in ProgramData\Microsoft\Provisioning and no C:\Recovery\Customizations (06). Fleet still shows host 25 offline with its 08:58 enrollment (host-25-still-offline). The host is gone from Fleet's reach: no agent, no MDM, nothing in Fleet says why.

## Result: PASS

With no package left, the reset comes back without fleetd and the host never checks in; the package is what brings it back

_Finished 2026-10-27T09:40:54Z_
- `007-fleet-host-25-after.jpg` (Fleet UI, Chrome; about 2 hours after the reset: Offline, MDM status still On (manual), though the host has no fleetd and no MDM)
