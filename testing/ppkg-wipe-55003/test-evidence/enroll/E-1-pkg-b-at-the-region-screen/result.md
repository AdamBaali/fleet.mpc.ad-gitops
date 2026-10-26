# E-1: PKG-B at the region screen

- **Started:** 2026-10-26T17:55:26Z
- **Objective:** Apply the bypass package during setup and see whether the host enrolls before any user exists
- **Expected:** Enrolls during setup with no sign-in prompt; MDM On after the first sign-in

## Steps and evidence
- `01-fleet-before.txt`: `fleetctl api '/api/v1/fleet/hosts?fleet_id=10' 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdi`
- `02-clone.txt`: `vm/clone.sh new ppkg-golden-oobe e1-bypass && vm/attach-usb.sh e1-bypass out/usb-pkg-b.img && /usr/libexec/Pli`
- `03-region-screen-usb-attached.png` (window screenshot: UTM / e1-bypass)
- `04-after-windows-key-x5.png` (window screenshot: UTM / e1-bypass)
- `05-package-opened.png` (window screenshot: UTM / e1-bypass)
- `06-after-password.png` (window screenshot: UTM / e1-bypass)
- `07-password-typing-check.png` (window screenshot: UTM / e1-bypass)
- `08-plain-package-opened.png` (window screenshot: UTM / e1-bypass)
- `09-after-yes-add-it.png` (window screenshot: UTM / e1-bypass)
- `10-fleet-host.txt`: `fleetctl api /api/v1/fleet/hosts/21 2>/dev/null | python3 -c 'import json,sys; h=json.load(sys.stdin)["host"];`
- `11-vm-state.txt`: `tools/vm-exec.sh e1-bypass 'Get-Service "Fleet osquery" | Format-Table Name,Status | Out-String; "local users:`
- `12-provisioning-log.txt`: `tools/vm-exec.sh e1-bypass 'Get-WinEvent -LogName Microsoft-Windows-Provisioning-Diagnostics-Provider/Admin -M`
- `13-vm-after-enrollment.png` (window screenshot: UTM / e1-bypass)

How the package went in: UTM's USB disk shows as a fixed disk, so the region screen didn't offer it, and Windows key x5 did nothing (03, 04). Opened from Shift+F10 instead: 'start fleet-agent-b.ppkg' showed 'Enter the package password' (05). The encrypted package built with ICD.exe +Encrypted failed with 'Provisioning failure 0x80070490' (06) although the typed password matched (07, checked against a hash). The same package built unencrypted showed 'Is this package from a source you trust?' (08) and applied on 'Yes, add it' at 18:03:57 UTC (09). Lab differences: shell-open instead of USB auto-detect, unencrypted package.

Result: fleetd installed and running at the region screen with no user account (only defaultuser0). Fleet host 21 DESKTOP-JVO75AD, UUID 6F2E8E70-..., fleet 10, last_enrolled_at 18:04:31Z, no end user and no IdP link. No browser or 'Get an app' prompt. MDM shows 'On (manual)' already during setup: the Fleet MDM enrollment is in HKLM\SOFTWARE\Microsoft\Enrollments. The guide says MDM turns on only after a user signs in; here fleetd turned it on during setup.

## Result: PARTIAL

Bypass build enrolls at the region screen with no prompt (host 21, 34 s after the package applied), and MDM is On before any user exists. Caveat: unencrypted package opened from Shift+F10; the ICD-encrypted package failed with 0x80070490.

_Finished 2026-10-26T18:06:34Z_
