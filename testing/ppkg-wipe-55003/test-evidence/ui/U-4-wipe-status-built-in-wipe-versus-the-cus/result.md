# U-4: Wipe status: built-in Wipe versus the custom command

- **Started:** 2026-10-27T09:39:48Z
- **Objective:** Read how Fleet records a Windows wipe at fleet-v4.93.0, and compare with the host pages after custom wipes (X-2, X-4)
- **Expected:** Recorded for the design

## Steps and evidence
- `01-built-in-wipe-sets-wipe-ref.txt`: `git -C <fleet repo> show fleet-v4.93.0:server/datastore/mysql/microsoft_mdm.go | sed -n `
- `02-result-matches-any-remotewipe.txt`: `git -C <fleet repo> show fleet-v4.93.0:server/datastore/mysql/microsoft_mdm.go | sed -n `
- `03-result-updates-only-wipe-ref-rows.txt`: `git -C <fleet repo> show fleet-v4.93.0:server/datastore/mysql/microsoft_mdm.go | sed -n `
- `04-re-enrollment-clears-mdm-actions.txt`: `git -C <fleet repo> show fleet-v4.93.0:server/datastore/mysql/hosts.go | sed -n 2645,265`

The built-in Wipe (WipeHostViaWindowsMDM) writes the command UUID to host_mdm_actions.wipe_ref, which drives the host page's wipe state. A custom command is never written there. When any RemoteWipe result comes back, Fleet updates host_mdm_actions only where wipe_ref matches, so a custom reprovision wipe changes nothing: the host page after X-2 and X-4 shows no wipe state (X-2 007 and 008, X-4 014). EnrollOrbit also deletes the host's host_mdm_actions row when fleetd re-enrolls. So if the reprovision types were added to the built-in Wipe as they are, "Wipe pending" would show until the host came back, and then the state would be cleared, not shown as "Wiped". The design needs its own record of a reprovision reset.

## Result: PASS

Custom reprovision wipes leave no wipe state; even the built-in Wipe's state is cleared when fleetd re-enrolls, so a reprovision reset needs its own record

_Finished 2026-10-27T09:39:48Z_
