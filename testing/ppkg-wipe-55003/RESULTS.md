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
| Does the cloud variant work? | Yes. `doWipeCloudPersistProvisionedData` downloaded an image for about 36 minutes while setup stayed on screen, then reset; same host back with MDM on, 57 minutes in total | C-5 |
| Does a second reset of the same host work? | Yes, same result and time (13 minutes) | C-3 (X-1) |
| What if the host is off when the wipe is sent? | Fleet queues it. The host runs it at its next check-in and comes back as in C-1. The activity feed shows the time it was sent, not when it ran | X-2 |
| What if the enroll secret was rotated after the package was built? | fleetd comes back after the reset but can't enroll ("unauthenticated, or invalid token"), and Fleet shows nothing: the host just stays offline. It enrolled 21 s after the old secret was valid again | X-3 |
| Which fleet does a reset host come back to? | The fleet it was in, not the fleet of the package's enroll secret. Fleet sets the fleet only when it creates a new host | X-4 |
| Can the Fleet wipe API send the reprovision wipe? | No. It accepts only `doWipe` and `doWipeProtected`, and rejects the others with a generic 400 | A-3 |
| What if end user authentication is off and the host was deleted? | The no-bypass build enrolls as a new host with no prompt and no end user, like the bypass build | X-6 |
| What if there's no package left? | The reset comes back without fleetd, and the host never checks in again. The package is what brings it back | X-7 |
| Does Fleet show that a host is being reset? | No. Mid-reset it shows Offline with MDM still On. After it, the feed shows the command (when sent) and "MDM turned on". The built-in Wipe's status would also be cleared when fleetd re-enrolls | U-1 to U-4 |
| Who can send the wipe and stage the package? | Admins, maintainers and GitOps users can send the wipe (same check as the built-in Wipe). Admins, maintainers and technicians can run the staging script | P-1 |

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
11. Bug: once the host re-enrolls, `fleetctl get mdm-command-results` for its wipe command fails with "converting NULL to
   string is unsupported". `GetMDMWindowsCommandResults` (`server/datastore/mysql/microsoft_mdm.go:1840` at
   fleet-v4.93.0) takes `host_uuid` from the enrollment that ran the command, which re-enrollment or host deletion
   removes (C-5, all wipe commands in this run).
12. A known host comes back in the fleet it was in, not the fleet of the package's enroll secret. `EnrollOrbit`
   (`server/datastore/mysql/hosts.go` at fleet-v4.93.0) sets the fleet only for a new host (X-4). A host moved to another
   fleet before the reset stays there.
13. Enroll secret rotation strands reset hosts. With a package built on an old secret, fleetd comes back and retries
   ("unauthenticated, or invalid token"), and Fleet shows the host as offline with nothing else (X-3). Rebuild and
   re-stage the package when the secret changes.
14. The wipe API rejects the reprovision types with a generic "failed to unmarshal request body" (A-3), because
   `MDMWindowsWipeType` knows only `doWipe` and `doWipeProtected`.
15. Re-staging the package fails while the host sits at Windows setup after a reset: Windows holds
   `C:\Recovery\Customizations\fleet-agent.ppkg` open (X-6). Lab case; a host in use is past setup.
16. The Provisioning failure 0x800700b7 seen in C-1, C-2 and X-6 is error 183, ERROR_ALREADY_EXISTS. Each time a USB
   drive was in at boot and setup applied the package by itself; in X-6 fleetd was already installed. Likely cause, not
   proven. Lab case.

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
| C-5 | PASS | Cloud variant: about 36 min download plus 21 min reset, same host back with MDM on |
| X-1 | PASS | Second reset of the same host (in C-3) |
| X-2 | PASS | Wipe sent while off runs at the next check-in; same host back |
| X-3 | PASS | Secret rotated: fleetd back but can't enroll; enrolls 21 s after the secret is valid again |
| X-4 | PASS | Host moved to No team stays in No team after the reset |
| X-5 | NOT-RUN | Older fleetd in the package: needs a package rebuild on the builder VM |
| X-6 | PASS | End user authentication off: deleted host enrolls as a new host, no prompt, no end user |
| X-7 | PASS | No package left: reset comes back without fleetd, host never checks in |
| X-8 | BLOCKED | BitLocker needs a TPM; the QEMU arm VMs have none |
| U-1 to U-4 | PASS | Host page and feed recorded; no wipe state for the custom command |
| A-3 | PASS | Wipe API rejects the reprovision types (generic 400) |
| P-1 | PASS | From code: admins, maintainers, GitOps can wipe; admins, maintainers, technicians can stage |
