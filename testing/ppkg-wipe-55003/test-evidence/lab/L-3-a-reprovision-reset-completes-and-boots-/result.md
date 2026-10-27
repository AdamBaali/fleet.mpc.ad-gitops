# L-3: A reprovision reset completes and boots in the lab

- **Started:** 2026-10-26T23:53:56Z
- **Objective:** On the generalized QEMU VM with no Fleet, call doWipePersistProvisionedData locally through the MDM WMI bridge (MDM_RemoteWipe) as SYSTEM, then watch
- **Expected:** Reset completes and Windows boots to the region screen

## Steps and evidence
- `01-before.txt`: `tools/qga.sh smoke 'hostname; (Get-CimInstance Win32_OperatingSystem).InstallDate'`
- `02-wipe.txt`: `tools/qga.sh smoke 'Invoke-CimMethod -Namespace root\cimv2\mdm\dmmap -ClassName MDM_RemoteWipe -MethodName doW`

The first call failed: Invoke-CimMethod needs a typed parameter. Retried with a CimSession and a String parameter, the usual form for the MDM WMI bridge.
- `03-wipe-cimsession.txt`: `tools/qga.sh smoke '$ns="root\cimv2\mdm\dmmap"; $s=New-CimSession; $p=New-Object Microsoft.Management.Infrastr`
- `03-wipe-cimsession.txt`: `tools/qga.sh smoke "$(cat payloads/local/wipe-persist-local.ps1)" 60`

Timeline (UTC, watch/watch.log and watch/*.png): wipe called 23:55:15, "Resetting this PC" from 23:55:30, region screen at 00:06:48. About 11.5 minutes. The guest agent never answers after the reset because the reset removes UTM guest tools, so the watcher ran to its stop and screens are the record. After the reset, a command prompt over setup (Shift+F10) takes typed input once its title bar is clicked (tools/qmp.sh shell).

## Result: PASS

doWipePersistProvisionedData, called locally through the MDM WMI bridge, reset the generalized VM and Windows booted back to the region screen in 11.5 minutes on Homebrew QEMU. First post-reset boot in this lab.

_Finished 2026-10-27T00:08:40Z_
