# C-3: No-bypass package, host deleted, new user signs in

- **Started:** 2026-10-27T03:05:36Z
- **Objective:** Host 27 from C-2r (no-bypass package kept, end user eua-user-1 in Fleet). Send doWipePersistProvisionedData, delete the host in Fleet once the device acknowledges it, then at the setup screen sign in as eua-user-2. Second reset of this host, so it also covers X-1
- **Expected:** Fleet blocks enrollment until sign-in; the sign-in page appears on the setup screen; host enrolls with only eua-user-2

## Steps and evidence
- `03-wipe-command.txt`: `fleetctl mdm run-command --hosts 1DE9FF32-F958-451B-A9A3-18E3B7D1860A --payload payloads/doWipePersistProvisio`
- `04-delete-host.txt`: `fleetctl api -X DELETE /api/v1/fleet/hosts/27`

Reset finished at the region screen at 03:18:42 (watch/033). For 8 minutes nothing else appeared: no Edge, no Fleet sign-in page, and the host was not in Fleet (fleet-poll.log). After a reset the package runs fleetd as a service only, so on the setup screen the next user is never asked to sign in, unlike first setup (C-2r 04, v1 E-2).
- `024-fleet-host-after.jpg` (Fleet UI, Chrome)

Wipe acknowledged 03:05:52 and host 27 deleted the same second (delete-host). Reset back at the region screen 03:18:42. Fleet refused enrollment every 30 s with end user authentication required (04, orbit log). No sign-in page on the setup screen (8 minutes watched).

Walked setup as the next user: region, keyboard, update check, license, skipped naming, local account lab2 through ms-cxh:localonly (05 to 12). At the first desktop the ramfb screen went black (13, lab display limit), so the VM was shut down over ACPI and started with virtio-gpu (viogpudo survived the reset). After the privacy screens (14, 15, options off) the desktop showed Edge on Fleet Authentication required (16). Edge offered Restore pages, so fleetd had already opened it at the first desktop, before the restart.

Signed in as eua-user-2 at 03:47:31 (17 to 19). Fleet created a new host 28 (DESKTOP-QMTG3I0, same UUID) at 03:47:39, enrolled 03:47:46, MDM On (manual), end users: only eua-user-2@example.com (20, Fleet UI). Lab: the IdP hosts line was typed at the region screen; a real IdP needs none.

## Result: PASS

Delete the host after the wipe acknowledges, and the reset host must authenticate again: Fleet blocks enrollment, fleetd opens the sign-in page at the new user desktop (not on the setup screen), and after eua-user-2 signs in Fleet shows a new host with only eua-user-2. Second reset of the host (X-1) also worked.

_Finished 2026-10-27T03:48:00Z_
