# C-3: No-bypass package, host deleted, new user signs in

**Objective:** Host 27 from C-2 (no-bypass package kept, end user `eua-user-1` in Fleet). Send `doWipePersistProvisionedData`, delete the host in Fleet once the device acknowledges it, then at the setup screen sign in as `eua-user-2`. Second reset of this host, so it also covers X-1  
**Expected:** Fleet blocks enrollment until sign-in; the sign-in page appears on the setup screen; host enrolls with only `eua-user-2`  
**Run:** 2026-10-27T03:05:36Z to 2026-10-27T03:48:00Z

## Evidence

- `03-wipe-command.txt`: `fleetctl mdm run-command --hosts 1DE9FF32-F958-451B-A9A3-18E3B7D1860A --payload payloads/doWipePersistProvisio`
- `04-delete-host.txt`: `fleetctl api -X DELETE /api/v1/fleet/hosts/27`
- `024-fleet-host-after.jpg` (Fleet UI, Chrome)
- `01-fleet-host-before.txt` (output)
- `02-screen-before.png` (VM screen)
- `03-hosts-line.png` (VM screen)
- `04-fleetd-refused.png` (VM screen)
- `05-keyboard.png` (VM screen)
- `06-next.png` (VM screen)
- `06-second-layout.png` (VM screen)
- `07-next.png` (VM screen)
- `08-next.png` (VM screen)
- `09-next.png` (VM screen)
- `10-next.png` (VM screen)
- `11-local-account.png` (VM screen)
- `12-after-account.png` (VM screen)
- `13-desktop.png` (VM screen)
- `14-after-restart.png` (VM screen)
- `15-privacy-2.png` (VM screen)
- `16-desktop-fleet-sign-in.png` (VM screen)
- `17-idp-login.png` (VM screen)
- `18-idp-filled.png` (VM screen)
- `19-auth-complete.png` (VM screen)
- `20-fleet-host-after.txt` (output)
- `fleet-poll.log`: the host's state in Fleet every 30 s
- `watch/`: first and last screen of the reset, and `watch.log`

## What happened

Reset finished at the region screen at 03:18:42 (watch/033). For 8 minutes nothing else appeared: no Edge, no Fleet
sign-in page, and the host was not in Fleet (fleet-poll.log). After a reset the package runs fleetd as a service only,
so on the setup screen the next user is never asked to sign in, unlike first setup (C-2 04, E-2).

Wipe acknowledged 03:05:52 and host 27 deleted the same second (delete-host). Fleet refused enrollment every 30 s with
end user authentication required (04, orbit log).

Walked setup as the next user: region, keyboard, update check, license, skipped naming, local account `lab2` through
`ms-cxh:localonly` (05 to 12). At the first desktop (13) and after the privacy screens (14, 15, options off), Edge
showed Fleet's "Authentication required" page (16): fleetd opened it at the first desktop.

Signed in as `eua-user-2` at 03:47:31 (17 to 19). Fleet created a new host 28 (DESKTOP-QMTG3I0, same UUID) at 03:47:39,
enrolled 03:47:46, MDM On (manual), end users: only `eua-user-2@example.com` (20, Fleet UI). Lab: the IdP hosts line was
typed at the region screen; a real IdP needs none.

## Result: PASS

Delete the host after the wipe acknowledges, and the reset host must authenticate again: Fleet blocks enrollment, fleetd
opens the sign-in page at the new user desktop (not on the setup screen), and after `eua-user-2` signs in Fleet shows a
new host with only `eua-user-2`. Second reset of the host (X-1) also worked.
