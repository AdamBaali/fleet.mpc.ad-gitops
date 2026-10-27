# E-2: PKG-N at the region screen

- **Started:** 2026-10-26T18:12:05Z
- **Objective:** Apply the no-bypass package during setup on a fleet that requires end user authentication
- **Expected:** Fleet blocks enrollment; fleetd tries to open the sign-in page; host not in Fleet during setup

## Steps and evidence
- `01-clone.txt`: `vm/clone.sh new ppkg-golden-oobe e2-nobypass && vm/attach-usb.sh e2-nobypass out/usb-pkg-n-plain.img >/dev/nul`
- `02-region-screen.png` (window screenshot: UTM / e2-nobypass)
- `03-trust-prompt.png` (window screenshot: UTM / e2-nobypass)
- `04-after-yes-90s.png` (window screenshot: UTM / e2-nobypass)
- `05-fleet-and-orbit-log.txt`: `fleetctl get hosts --team 10 --json 2>/dev/null | wc -l | xargs echo hosts in fleet 10:; tools/vm-exec.sh e2-n`
- `06-edge-after-start-without-data.png` (window screenshot: UTM / e2-nobypass)
- `07-edge-3.png` (window screenshot: UTM / e2-nobypass)
- `08-edge-4.png` (window screenshot: UTM / e2-nobypass)
- `09-fleet-sign-in-page.png` (window screenshot: UTM / e2-nobypass)
- `10-idp-login-page.png` (window screenshot: UTM / e2-nobypass)
- `11-after-idp-login.png` (window screenshot: UTM / e2-nobypass)
- `12-fleet-host-22.txt`: `fleetctl api /api/v1/fleet/hosts/22 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdin)["host"];`
- `13-orbit-log-after.txt`: `tools/vm-exec.sh e2-nobypass 'Get-Content C:\Windows\system32\config\systemprofile\AppData\Local\FleetDM\Orbit`
- `14-authentication-complete.png` (window screenshot: UTM / e2-nobypass)

Applied fleet-agent-n-plain.ppkg from Shift+F10 at 18:13:43 UTC (same method as E-1). fleetd started and Fleet refused enrollment every 30 s with end user authentication required (no prior record for UUID C87CFBCE-...). Unlike the guide (Troubleshoot: Get an app to open this https link), Windows 11 26H2 opened Microsoft Edge on the setup screen: first-run pages (04 to 08, privacy-preserving choices), then Fleet sign-in https://fleet.mpc.ad/mdm/sso?initiator=setup_experience&host_uuid=... (09). Sign in went to the mock IdP at idp.ppkg.test (10). Signed in as eua-user-1 at 18:17:52 UTC: Fleet showed Authentication complete (11). fleetd enrolled at 18:18:07 local log time, called RegisterDeviceWithManagement, and Fleet listed host 22 at 18:18:20 with end user eua-user-1@example.com and MDM On (manual). No Windows account existed yet (only defaultuser0).

## Result: PASS

No-bypass build: Fleet blocks enrollment until the IdP sign-in, which happens in Edge on the setup screen (26H2 has a browser there). Host 22 enrolled 28 s after sign-in with the IdP user linked and MDM On, before any user account.

_Finished 2026-10-26T18:19:06Z_
- `15-local-account-screen.png` (window screenshot: UTM / e2-nobypass)
- `16-privacy-choices.png` (window screenshot: UTM / e2-nobypass)
- `17-privacy-2.png` (window screenshot: UTM / e2-nobypass)
- `18-privacy-3.png` (window screenshot: UTM / e2-nobypass)
- `19-desktop-lab1.png` (window screenshot: UTM / e2-nobypass)

Finished setup as lab1 (no password, privacy options off). Desktop at 18:21 UTC with no further prompt: the IdP sign-in had already happened on the setup screen. Fleet: host 22 online, MDM On (manual), end user eua-user-1@example.com.
