# Results: reset a Windows host with a provisioning package (fleetdm/fleet#55003)

Lab runs 2026-10-26 and 27, Fleet 4.93.0, fleet 10 "Windows Reset Lab" (end user authentication on, mock SAML IdP),
Windows 11 Pro 26H2 (26300.9457) arm64. v1 ran in UTM; from 2026-10-27 VMs run on Homebrew QEMU 11.1.2 (NOTES, "Lab
fix"). Evidence per test in `test-evidence/`.

## What we know now

| Question | Answer | Evidence |
|---|---|---|
| Does the bypass build enroll during setup? | Yes. Enrolled about 30 s after the package applied, with no prompt, before any user account. MDM was On before any user existed | E-1, E-1b |
| Does the no-bypass build wait for the IdP? | Yes. Fleet refuses enrollment ("end user authentication required") until the sign-in | E-2 |
| Where does the end user sign in? | On the setup screen. Windows 11 26H2 opens Microsoft Edge there, so fleetd shows Fleet's "Authentication required" page, then the IdP. Host enrolled 28 s after sign-in with the IdP user linked and MDM On, before any account existed | E-2 |
| Does `doWipePersistProvisionedData` keep the package? | Yes. The package applied at setup stays in `C:\ProgramData\Microsoft\Provisioning`. The device is wiped: user profile and files gone | W-1b |
| Can Fleet stage the package on a host enrolled another way? | Yes. A Fleet script copied it into `C:\Recovery\Customizations` (exit 0). The reset kept it and processed it (`InstallOrder.ini` written during the reset). Same pattern as Omnissa's Workspace ONE script (NOTES D-7) | W-6 |
| Does it work for a host that was never set up with a package (brownfield)? | Yes. A Fleet script staged the package in `C:\Recovery\Customizations` on an MSI-enrolled host; after the wipe the reset applied it and the host came back as the same Fleet host in 12.5 minutes with MDM on | C-4 |
| Does the host come back to Fleet after the reset? | Yes (bypass build). 13 minutes after the wipe, fleetd had reinstalled itself and re-enrolled at the region screen as the same Fleet host, with no prompt. Windows MDM re-enrolled a minute later. The local user and its files were gone; the package was still kept | C-1 |
| Does the no-bypass host need the IdP again after the reset? | No, if the host is still in Fleet. It came back as the same host in 13 minutes with nobody signing in: Fleet lets a host it already knows re-enroll without end user authentication | C-2r |
| Does a repurposed host keep the old IdP user? | Yes. After the reset Fleet still shows the previous user (eua-user-1) as the host's end user, and the next person isn't asked to sign in. To get a new user, the host has to be deleted from Fleet | C-2r |
| If the admin deletes the host during the reset, does the next user get asked to sign in? | Yes, but at the desktop, not on the setup screen. Fleet blocks enrollment after the reset; nothing appears during setup; once the new user reaches the desktop, fleetd opens Fleet's sign-in page. After sign-in Fleet lists a new host with only the new IdP user | C-3 |
| Does a second reset of the same host work? | Yes, same result and time (13 minutes) | C-3 (X-1) |

## Lab blocker, fixed

In v1 every Windows rebuilt by a reset or generalize hung at the UEFI "Start boot option" screen in UTM 4.7.5. The same
disk boots on Homebrew QEMU 11.1.2 with its edk2 (L-2C), and a reset completes and boots in 11.5 minutes (L-3). The
lab now runs headless on QEMU with scripts for screens, keys, and guest commands (NOTES, "Lab fix").

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
   MSI with the enroll secret. The v1 staging script left Users with read access to `C:\Recovery`; fixed, and C-4 shows only SYSTEM and
   Administrators.
6. Fleet keys Windows MDM enrollments on `mdm_hardware_id`. Clones of one non-generalized image share it, so a second
   clone took over the first one's MDM record. Lab artifact here, but relevant for cloned VDI images.
7. After a custom wipe command, Fleet keeps showing the host as MDM On and connected until it checks in again. Right
   after the reset Fleet briefly refused MDM commands to the host ("MDM turned off") while Windows re-enrolled (C-1).
8. Lab: packages built with `ICD.exe ... +Encrypted` failed to apply (0x80070490) though the password matched. Tests used
   unencrypted packages. The guide's Configuration Designer GUI was not tested.
9. The host page's "Added to Fleet" shows `last_enrolled_at`, so a reset host looks newly added though `created_at`
   and the host ID are unchanged (C-1).
10. Nothing in Fleet records that the host was wiped: the activity feed shows the custom command and a new "MDM turned
   on", and the host has no wipe status (C-1, U-4).

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
| W-2, W-3, W-5 | NOT-RUN | Replaced by plan v2 tests C-2, C-3, C-5 |
| L-2C, L-3 | PASS | Lab fix: generalize and reset boot on Homebrew QEMU |
| C-1 | PASS | Bypass build: host reset by doWipePersistProvisionedData from Fleet comes back to the same Fleet host, MDM on, no prompt |
| C-2 | BLOCKED | Lab display fault mid-reset; rerun as C-2r |
| C-2r | PASS | No-bypass build: same host back in 13 min without the IdP; previous end user still attributed |
| C-3 | PASS | Host deleted during the reset: new host, sign-in at the new user's desktop, only the new IdP user |
| C-4 | PASS | Brownfield: Fleet script stages the package in C:\Recovery\Customizations; same host back in 12.5 min, MDM on |
