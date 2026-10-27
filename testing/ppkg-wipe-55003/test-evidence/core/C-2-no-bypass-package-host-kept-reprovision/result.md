# C-2: No-bypass package, host kept, reprovision reset

**Objective:** PKG-N on a generalized VM in fleet 10 (end user authentication on), opened from a USB drive with Shift+F10 at the region screen as in E-2. Sign in to the IdP as `eua-user-1`, then `doWipePersistProvisionedData` from Fleet with the host left in Fleet  
**Expected:** Fleet lets the reset host back in without the IdP (`HostPreviouslyOrbitEnrolled`); record which end user Fleet shows afterwards  
**Run:** 2026-10-27T02:39:03Z to 2026-10-27T03:04:59Z

## Evidence

- `015-fleet-host-before.jpg` (Fleet UI, Chrome)
- `15-wipe-command.txt`: `fleetctl mdm run-command --hosts 1DE9FF32-F958-451B-A9A3-18E3B7D1860A --payload payloads/doWipePersistProvisio`
- `18-live-query-after.txt`: `fleetctl query --hosts 1DE9FF32-F958-451B-A9A3-18E3B7D1860A --exit --timeout 90s --query "$(cat queries/after-`
- `020-fleet-host-after.jpg` (Fleet UI, Chrome)
- `01-region-screen.png` (VM screen)
- `03-usb-inserted.png` (VM screen)
- `04-trust-prompt.png` (VM screen)
- `05-edge-2.png` (VM screen)
- `06-edge-3.png` (VM screen)
- `07-edge-3-unticked.png` (VM screen)
- `08-edge-4.png` (VM screen)
- `09-fleet-sign-in.png` (VM screen)
- `10-idp-login.png` (VM screen)
- `11-idp-filled.png` (VM screen)
- `12-auth-complete.png` (VM screen)
- `13-auth-complete.png` (VM screen)
- `14-fleet-host-before.txt` (output)
- `20-fleet-host-activities.txt` (output)
- `21-fleet-host-after.txt` (output)
- `fleet-poll.log`: the host's state in Fleet every 30 s
- `watch/`: first and last screen of the reset, and `watch.log`

## What happened

Package opened from Shift+F10 at about 02:40 UTC (03, 04). fleetd started and opened Edge on the setup screen by itself
(04). Edge first run with data import and personalization unticked (05 to 08), Fleet Authentication required (09), mock
IdP (10, 11), signed in as `eua-user-1` at 02:42:50, Authentication complete (12, 13). Host 27 (DESKTOP-M8HO67K, UUID
1DE9FF32-...) enrolled 02:43:23 in fleet 10, MDM On (manual), end user `eua-user-1@example.com` (14). Package kept in
ProgramData; markers written; USB disk unplugged before the wipe.

**Timeline (UTC):** wipe sent 02:43:45, host offline 02:45:24, reset screens in watch/, fleetd re-enrolled 02:56:54 at
the region screen (same host 27, new hostname), mdm_enrolled 02:57:50 (20). 13 minutes. Nobody signed in after the
reset: no browser opened, the hosts line for the IdP was gone with the reset, and the region screen sat untouched
(watch/037). Fleet let the host back in without end user authentication, as the code predicts for a host it already
knows (`HostPreviouslyOrbitEnrolled`, NOTES D-1).

**Repurposing finding:** after the reset Fleet still shows `eua-user-1@example.com` as the host end user (21, Fleet UI
020-fleet-host-after.jpg). The next person to set up this host is not asked to sign in, and the previous user stays
attributed. To get a new IdP user the admin must delete the host from Fleet before or during the reset (C-3).

**Live query at the region screen (live-query-after):** local users only built-in accounts, 0 markers left, fleetd
RUNNING, `fleet-agent-n-plain.ppkg` still kept, uptime 464 s.

## Result: PASS

No-bypass package + `doWipePersistProvisionedData`: host came back as the same Fleet host 27 in 13 min with no IdP
sign-in and MDM re-enrolled; Fleet keeps the previous end user `eua-user-1` attributed (repurposing gap).
