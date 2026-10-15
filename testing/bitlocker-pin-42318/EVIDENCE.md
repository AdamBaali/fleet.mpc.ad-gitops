# Evidence: BitLocker PIN (#42318), 2026-10-15

Lab: Fleet 4.93.0 (`https://fleet.mpc.ad`, `FLEET_MDM_ENABLE_CUSTOM_DISK_ENCRYPTION=true`), fleet 7 "Windows BitLocker Lab",
host 15, Windows 11 Pro 26H2 (26300) arm64 VM in UTM with TPM 2.0 (not Modern Standby). Full log: `RESULTS.md`.
Code/doc research: `notes/research-2026-10-15.md`.

| ID | What | Result | Evidence |
|---|---|---|---|
| S-1b | Device class | INFO: not Modern Standby (`powercfg /a`), desktop (PCSystemType 1), swtpm TPM 2.0, Secure Boot off | `test-evidence/S-1/01-host-facts.txt`, `02-tpm.txt` |
| S-2 | Enroll in fleet 7 (Windows MDM) | PASS | `test-evidence/S-2/01-install.txt` |
| S-3 | Fleet 4.93.0 accepts a BitLocker profile with the server option on | PASS | `test-evidence/S-setup/S-3-upload-profile-A.txt` |
| S-4 | Fleet encrypts C: (TPM protector, key escrowed) | PASS after detaching install ISOs (first try failed: "detected bootable media (CD or DVD)") | `RESULTS.md` 13:37, 13:46 |
| B-1 | Fleet's PIN payload on the host | PASS: UseTPM/UseTPMPIN/UseTPMKey/UseTPMKeyPIN = 2, MinimumPIN 6, UseEnhancedPin 1 | `test-evidence/B/01-B1-registry.txt` |
| B-2 | Manage BitLocker with Fleet's payload (admin) | Bug NOT reproduced: "Change how drive is unlocked at startup" -> "Enter a PIN (recommended)"; PIN added on the encrypted drive | `test-evidence/B/03-B2-manage-bitlocker.png`, `04-B2-after-click-change.png`, `test-evidence/P/01-after-pin.txt` |
| B-3 | Refetch with PIN required | PASS: no stall | `RESULTS.md` 13:47 |
| B-4 | My device "Create PIN" (fleetd 1.61.0) | Old Manage BitLocker instructions, not the 4.93 form | `test-evidence/B/07-B4-my-device-3.png`, `08-B4-create-pin-click.png` (URL masked) |
| P | Pre-boot PIN prompt | BLOCKED: UTM never shows Windows Boot Manager's BitLocker screen; needs real hardware | `test-evidence/P/` |
| N-2 | Custom profile C (PIN Required, others Disallowed) + Fleet encryption on, **standard user, no Fleet Desktop** | Profile Verified; Fleet didn't override it (also after a refetch). **No prompt; TPM-only protector kept; Manage BitLocker asks for admin credentials.** Fleet: "action_required / create_pin" | `test-evidence/N2/04-after-profile-C.txt`, `05-labuser-manage-bitlocker.png`, `06-labuser-click-change.png` |
| N-2b | Same, an **admin** adds the PIN | PASS: "Enter a PIN" works with Required; protectors RecoveryPassword + TpmPin; "Change PIN" shown; **Fleet: Verified** | `test-evidence/N2/08-admin-pin-1.png`, `11-after-admin-pin.txt`, `12-after-pin-now.png`; `RESULTS.md` 14:53 |
| N-1 | "Only USB is offered" + `SystemDrivesEnablePrebootInputProtectorsOnSlates` | NOT-RUN: needs a device like the customer's | `profiles/D - ...xml` ready |
| N-3 | Lockout after 3 failed PIN attempts | NOT-RUN. Researched: Windows locks TPM 2.0 after 32 failures (Microsoft TPM fundamentals); only a legacy Group Policy changes it | `ISSUE_UPDATE.md` |

Screenshots never show a PIN (dots only) or a recovery key; My device screenshots have the address bar (device token) masked.

## Screenshots (window-only, from the VM; no PIN or recovery key visible)
Gaps: there are **no Fleet UI screenshots** (Fleet's status, "Action required" -> "Verified" and profile "Verified", was read from
the API; see `RESULTS.md`), and the VM and host were deleted before that was noticed. The pre-boot screen can't be captured in UTM.

### Setup
First build's blue screen (S-1, failed build): ![UNMOUNTABLE_BOOT_VOLUME](test-evidence/S-setup/13-setup.png)

Second build at the desktop (S-1): ![Desktop](test-evidence/S-setup2/90-desktop.png)

### B-2: Fleet's own PIN payload, admin user (bug not reproduced)
Manage BitLocker shows "Change how drive is unlocked at startup": ![Manage BitLocker](test-evidence/B/03-B2-manage-bitlocker.png)

Clicking it offers "Enter a PIN (recommended)": ![Choose how to unlock](test-evidence/B/04-B2-after-click-change.png)

After the PIN was set, "Change PIN" appears: ![Change PIN](test-evidence/P/02-after-pin-dialog.png)

### B-4: My device with fleetd 1.61.0 (address bar masked)
Banner "Create a BitLocker PIN": ![My device banner](test-evidence/B/07-B4-my-device-3.png)

"Create PIN" opens the old Manage BitLocker instructions: ![Create PIN instructions](test-evidence/B/08-B4-create-pin-click.png)

### P: pre-boot PIN in UTM (blocked)
After reboot, the screen stays on the firmware frame: ![Firmware frame](test-evidence/P/03-now.png)

With `virtio-gpu-pci`, Windows Boot Manager starts and draws nothing: ![Boot manager](test-evidence/P/virtio-gpu/05.png)

### N-2: PIN Required profile, standard user `labuser`, no Fleet Desktop
Desktop, nothing from Fleet: ![labuser desktop](test-evidence/N2/02-labuser-desktop.png)

Manage BitLocker as a standard user: ![labuser Manage BitLocker](test-evidence/N2/05-labuser-manage-bitlocker.png)

"Change how drive is unlocked at startup" asks for an admin username and password: ![UAC admin credentials](test-evidence/N2/06-labuser-click-change.png)

### N-2b: admin adds the PIN with PIN Required
"Enter a PIN" (dots only): ![Enter a PIN](test-evidence/N2/08-admin-pin-1.png)

After: "Change PIN", "some settings are managed by your system administrator", no "Change how drive is unlocked": ![After admin PIN](test-evidence/N2/12-after-pin-now.png)

### #27903 side tests
T2, `manage-bde -w C:` and the "Wiping of free space on volume C: completed" event: ![Wipe](test-evidence/27903/06-T2-after-wipe.png)

T3, the data drive stays unencrypted ("Data27903 (F:) BitLocker off"): ![F: off](test-evidence/27903/23-T3-control-panel.png)

(`27903/20-T3-screen-1.png` is a second copy of the T2 screen, not a T3 screenshot.)
