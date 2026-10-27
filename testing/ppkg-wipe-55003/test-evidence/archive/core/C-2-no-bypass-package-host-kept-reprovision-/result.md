# C-2: No-bypass package, host kept, reprovision reset

- **Started:** 2026-10-27T00:47:09Z
- **Objective:** PKG-N on a generalized QEMU VM in fleet 10 (end user auth on). Sign in to the IdP as eua-user-1 at setup, then doWipePersistProvisionedData from Fleet with the host left in Fleet
- **Expected:** Fleet lets the reset host back in without the IdP (HostPreviouslyOrbitEnrolled); record which end user Fleet shows afterwards

## Steps and evidence

Setup applied fleet-agent-n-plain.ppkg from the USB drive by itself (QEMU presents a true removable drive), fleetd installed and Fleet refused enrollment with end user authentication required, but setup showed Provisioning failure 0x800700b7 (setup-watch/002), as in C-1. Unplugged the drive and restarted Windows to get back to the region screen. After that restart fleetd runs only as a service and can no longer open Edge in the setup session (in v1 E-2 it did, straight after the package applied), so the Fleet sign-in URL from E-2 was opened by hand from Shift+F10. Lab deviation, not the customer flow.

QEMU display switched from ramfb to virtio-gpu (viogpudo from UTM guest tools) because ramfb showed stale screens. Edge opened by typing start msedge with the E-2 sign-in URL (01): Fleet Authentication required, Sign in, mock IdP (02, 03), signed in as eua-user-1, Fleet Authentication complete at about 01:06:40 UTC (04). Host 26 (DESKTOP-LOLO2H4, UUID 48967B81-...) enrolled 01:07:01 in fleet 10, MDM On (manual), end user eua-user-1@example.com (05). Marker files written to C:\lab-marker.txt and C:\Users\lab1-data. Setup not finished as a local user (same keyboard limits as C-1).
- `006-fleet-host-before.jpg` (Fleet UI, Chrome)
- `06-wipe-command.txt`: `fleetctl mdm run-command --hosts 48967B81-B90A-4ECF-BC39-D22CF53F7D8D --payload payloads/doWipePersistProvisio`

Lab: from 01:18 the virtio-gpu screen said Display output is not active (watch/006) and QEMU sat at about 2% CPU for 10 minutes. The reset environment has no viogpudo. Power-cycled at about 01:30 with ramfb and virtio-gpu both attached, so the reset environment draws on ramfb.

After the power cycle the reset did not recover: Your device ran into a problem and could not be repaired (watch/008). Attempt abandoned. Fleet still lists host 26 with eua-user-1 (stale). Rerun as C-2r on a fresh VM with both displays from the start.

## Result: BLOCKED

Lab fault: the reset ran with only virtio-gpu, which the reset environment cannot draw on; it sat idle for 10 min, and a power cycle mid-reset left Windows unbootable. Rerun as C-2r.

_Finished 2026-10-27T01:36:07Z_
