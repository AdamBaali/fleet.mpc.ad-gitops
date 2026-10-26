# E-1b: PKG-B at the region screen, fresh host for the wipe tests

- **Started:** 2026-10-26T18:46:52Z
- **Objective:** Repeat E-1 on a new clone so its MDM enrollment is the only one with this hardware ID
- **Expected:** Enrolls during setup with MDM On; becomes the W-1 host

## Steps and evidence
- `01-region-screen.png` (window screenshot: UTM / w1-bypass)
- `02-trust-prompt.png` (window screenshot: UTM / w1-bypass)

Yes, add it at 18:48:33 UTC. Host 23 (UUID AB61C369-...) enrolled in fleet 10 and showed in fleetctl get hosts --mdm at 18:48:56, 23 s later, before any user account. Same as E-1.
- `03-privacy-1.png` (window screenshot: UTM / w1-bypass)
- `04-privacy-2.png` (window screenshot: UTM / w1-bypass)
- `05-desktop-lab1.png` (window screenshot: UTM / w1-bypass)
- `06-fleet-host.txt`: `fleetctl api /api/v1/fleet/hosts/23 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdin)["host"];`

## Result: PASS

Fresh bypass host 23: enrolled and MDM On during setup with no prompt; lab1 desktop reached with no prompt. Ready for W-1.

_Finished 2026-10-26T18:51:06Z_
