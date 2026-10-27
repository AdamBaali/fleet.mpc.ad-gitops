# C-4: Brownfield: Fleet stages the package, then reprovision reset

- **Started:** 2026-10-27T03:52:14Z
- **Objective:** Generalized QEMU VM enrolled with MSI-B only (no package at setup). Push the bypass package to C:\Windows\Temp (lab shortcut), run scripts/stage-ppkg.ps1 from Fleet to put it in C:\Recovery\Customizations, then doWipePersistProvisionedData from Fleet
- **Expected:** Same as C-1: host comes back to the same Fleet host with MDM on, no prompt; this is the Omnissa pattern (NOTES D-7)

## Steps and evidence
- `01-before-state.txt`: `tools/qga.sh c4 "Test-Path C:\Recovery\Customizations; (Get-ChildItem C:\ProgramData\Microsoft\Provisioning -F`
- `02-push-msi.txt`: `tools/qga-push.sh c4 out/msi-b/fleet-osquery-arm64.msi C:\Windows\Temp\fleet-osquery-arm64.msi`
- `02-push-msi.txt`: `tools/qga-push.sh c4 out/msi-b/fleet-osquery-arm64.msi C:/Windows/Temp/fleet-osquery-arm64.msi`
- `03-install-msi.txt`: `tools/qga.sh c4 "$(cat payloads/local/install-msi.ps1)" 300`
- `05-push-ppkg.txt`: `tools/qga-push.sh c4 out/fleet-agent-b-plain.ppkg C:/Windows/Temp/fleet-agent.ppkg`
- `06-markers.txt`: `tools/qga.sh c4 "$(cat payloads/local/markers.ps1)" 30`
- `07-fleet-run-script.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path scripts/stage-ppkg.ps1`
- `008-fleet-host-before.jpg` (Fleet UI, Chrome)
- `08-wipe-command.txt`: `fleetctl mdm run-command --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --payload payloads/doWipePersistProvisio`
- `09-live-query-after.txt`: `fleetctl query --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --exit --timeout 90s --query "$(cat queries/after-`
- `011-fleet-host-after.jpg` (Fleet UI, Chrome)

Brownfield host: generalized VM at the region screen, MSI-B installed through the guest agent (exit 0), host 29 (DESKTOP-4NHCNJG, UUID 1FCA0238-...) enrolled 03:54:31 with MDM On (03). No package in ProgramData\Microsoft\Provisioning and no C:\Recovery\Customizations before staging (before-state). The bypass package was pushed to C:\Windows\Temp (lab shortcut) and Fleet ran scripts/stage-ppkg.ps1: exit 0, same SHA-256 in C:\Recovery\Customizations, C:\Recovery now SYSTEM and Administrators only (fleet-run-script). The permissions fix from v1 W-6 works.

Timeline (UTC): wipe sent 03:56:08, host offline 03:58:42, fleetd re-enrolled 04:08:43 at the region screen (same host 29, new hostname), MDM Off for the first poll, then On at 04:09:30 (mdm_enrolled 04:09:38). 12.5 minutes, no prompt (watch/036). Live query (live-query-after): no package in ProgramData (the host never had one), fleet-agent.ppkg and InstallOrder.ini in C:\Recovery\Customizations, fleetd RUNNING, local users built-in only, 0 markers. So push-button reset re-applied the staged package by itself.

Fleet UI after (fleet-host-after): Hardware model shows -1 and Disk space No data available right after re-enrollment; host details had not refreshed yet.

## Result: PASS

Brownfield path works: a Fleet script staged the package in C:\Recovery\Customizations on an MSI-enrolled host, and after doWipePersistProvisionedData the host came back as the same Fleet host in 12.5 min with MDM on and no prompt.

_Finished 2026-10-27T04:10:23Z_
