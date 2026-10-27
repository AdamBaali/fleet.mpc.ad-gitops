# L-3: A reprovision reset completes and boots in the lab

**Objective:** On a generalized VM with no Fleet, call `doWipePersistProvisionedData` locally through the MDM WMI bridge (`MDM_RemoteWipe`) as SYSTEM, then watch  
**Expected:** Reset completes and Windows boots to the region screen  
**Run:** 2026-10-26T23:53:56Z to 2026-10-27T00:08:40Z

## Evidence

- `01-before.txt`: hostname and install date before
- `03-wipe-cimsession.txt`: `payloads/local/wipe-persist-local.ps1` (CimSession with a typed String parameter)
- `watch/` (VM screens): first and last screen of the reset, and `watch.log`

## What happened

**Timeline (UTC):** wipe called 23:55:15, "Resetting this PC" from 23:55:30, region screen at 00:06:48. About 11.5
minutes.

## Result: PASS

`doWipePersistProvisionedData`, called locally through the MDM WMI bridge, reset the generalized VM, and Windows booted
back to the region screen in 11.5 minutes.
