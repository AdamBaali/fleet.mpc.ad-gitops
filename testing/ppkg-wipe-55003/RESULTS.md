# Results: reset a Windows host with a provisioning package (fleetdm/fleet#55003)

Lab run 2026-10-26, Fleet 4.93.0, fleet 10 "Windows Reset Lab" (end user authentication on, mock SAML IdP), Windows 11
Pro 26H2 (26300.9457) arm64 in UTM. Evidence per test in `test-evidence/`.

## What we know now

| Question | Answer | Evidence |
|---|---|---|
| Does the bypass build enroll during setup? | Yes. Enrolled about 30 s after the package applied, with no prompt, before any user account. MDM was On before any user existed | E-1, E-1b |
| Does the no-bypass build wait for the IdP? | Yes. Fleet refuses enrollment ("end user authentication required") until the sign-in | E-2 |
| Where does the end user sign in? | On the setup screen. Windows 11 26H2 opens Microsoft Edge there, so fleetd shows Fleet's "Authentication required" page, then the IdP. Host enrolled 28 s after sign-in with the IdP user linked and MDM On, before any account existed | E-2 |
| Does `doWipePersistProvisionedData` keep the package? | Yes. The package applied at setup stays in `C:\ProgramData\Microsoft\Provisioning`. The device is wiped: user profile and files gone | W-1b |
| Can Fleet stage the package on a host enrolled another way? | Yes. A Fleet script copied it into `C:\Recovery\Customizations` (exit 0). The reset kept it and processed it (`InstallOrder.ini` written during the reset). Same pattern as Omnissa's Workspace ONE script (NOTES D-7) | W-6 |
| Does the host come back to Fleet after the reset? | Not observed. The reset Windows never booted in this lab | W-1b, W-6 |
| Does a repurposed host keep the old IdP user? | Not observed (needs the host to come back first) | W-2, W-3 not run |

## Blocker

Every Windows rebuilt by the reset hangs at the UEFI "Start boot option" screen under UTM/QEMU on arm64. Windows
Startup Repair finds 0 root causes. After `bcdboot` it fails with error 0xc0000001. Turning off VSM and the hypervisor
in the boot entry doesn't help. A sysprep `/generalize` image hangs the same way. This is a lab limit, not a Fleet
result: the first boot after a reset or generalize doesn't work on this hypervisor. The reset itself completes.

Next step: run W-1b, W-2, W-3, and W-6 on a physical x64 laptop (or an x64 Hyper-V VM). Everything else is ready:
packages, payloads, staging script, IdP, fleet.

## Findings to share

1. Guide (preinstall fleetd with a ppkg): "No web browser is available while Windows applies the package" and the "Get
   an app to open this 'https' link" troubleshooting are out of date for 26H2. Edge opens during setup, and the
   no-bypass flow works there.
2. Guide: "Windows MDM turns on after an end user signs in." Here MDM was On during setup, before any user.
3. Docs: the setup experience guide says `--bypass-end-user-auth` "only works if" `mdm.allow_orbit_end_user_auth_bypass`
   is `false`. The code and E-1 show the default `true` is what lets it work (NOTES D-2).
4. Docs: Fleet's MDM command library Windows payloads are wrapped in `<syncml>`, which `fleetctl mdm run-command`
   rejects. The bare `<Exec>` works (NOTES D-8).
5. Security: the package kept in `ProgramData\Microsoft\Provisioning` is readable by Users and Everyone. It holds the
   MSI with the enroll secret. The staging script left Users with read access to `C:\Recovery` too (fix in the script).
6. Fleet keys Windows MDM enrollments on `mdm_hardware_id`. Clones of one non-generalized image share it, so a second
   clone took over the first one's MDM record. Lab artifact here, but relevant for cloned VDI images.
7. After a custom wipe command, Fleet keeps showing the host as MDM On and connected until it checks in again.
8. Lab: packages built with `ICD.exe ... +Encrypted` failed to apply (0x80070490) though the password matched. Tests used
   unencrypted packages. The guide's Configuration Designer GUI was not tested.

## Test results

| ID | Result | Summary |
|---|---|---|
| S-0 to S-7 | PASS (S-6 lab method) | Lab, IdP, golden VM, MSIs, packages |
| E-1, E-1b | PARTIAL, PASS | Bypass enrolls during setup, MDM On, no prompt |
| E-2 | PASS | No-bypass: IdP sign-in in Edge on the setup screen, IdP user linked |
| E-3 | PASS | Package kept in ProgramData, readable by every user |
| W-1 | BLOCKED | Clones shared a Windows MDM hardware ID (fixed by running hosts in sequence) |
| W-1b | BLOCKED | Wipe and package kept; reset Windows doesn't boot in UTM |
| W-6 | BLOCKED | Fleet-staged package kept and processed; reset Windows doesn't boot in UTM |
| W-2, W-3, W-5 | NOT-RUN | Need a host that boots after a reset |
