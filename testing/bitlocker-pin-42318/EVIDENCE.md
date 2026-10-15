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
| P | Pre-boot PIN prompt | Earlier BLOCKED (hung); **PASS at 23:15**: PIN screen shown, wrong PIN rejected, 6th wrong PIN -> recovery | `test-evidence/P/`, `hw-workaround/21`–`27` |
| N-2 | Custom profile C (PIN Required, others Disallowed) + Fleet encryption on, **standard user, no Fleet Desktop** | Profile Verified; Fleet didn't override it (also after a refetch). **No prompt; TPM-only protector kept; Manage BitLocker asks for admin credentials.** Fleet: "action_required / create_pin" | `test-evidence/N2/04-after-profile-C.txt`, `05-labuser-manage-bitlocker.png`, `06-labuser-click-change.png` |
| N-2b | Same, an **admin** adds the PIN | PASS: "Enter a PIN" works with Required; protectors RecoveryPassword + TpmPin; "Change PIN" shown; **Fleet: Verified** | `test-evidence/N2/08-admin-pin-1.png`, `11-after-admin-pin.txt`, `12-after-pin-now.png`; `RESULTS.md` 14:53 |
| N-1 | "Only USB is offered" + `SystemDrivesEnablePrebootInputProtectorsOnSlates` | NOT-RUN: needs a device like the customer's | `profiles/D - ...xml` ready |
| N-3 | Lockout after 3 failed PIN attempts | Tested 22:18 (L-1/L-2 below): Fleet profile delivers the TPM lockout policy, result 32 failures / 2 h heal, not 3 | `close-out/34-L1-after-profile-H.txt` |

Screenshots never show a PIN (dots only) or a recovery key; My device screenshots have the address bar (device token) masked.

## Screenshots (window-only, from the VM; no PIN or recovery key visible)
Fleet UI screenshots exist for the close-out run's final state (below). Earlier runs' Fleet states are API output only. The pre-boot screen can't be captured in UTM.

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

### P: pre-boot PIN in UTM (earlier attempt, hung; see "Getting around the hardware" for the working run)
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

## Close-out run (2026-10-15, 20:28–21:00): the customer's setup, end to end
Host 16, fleet 7, fleetd 1.61.0 **without Fleet Desktop**, signed in as standard user `labuser`. Fleet state over time is from the
API (`test-evidence/close-out/*.txt`); the final state is also in Fleet UI screenshots below (taken 21:3x in Chrome; public IP masked).

| ID | What | Result | Evidence |
|---|---|---|---|
| C-1 | Fleet's own "Require BitLocker PIN" (no custom profile) | Fleet "action_required"; PIN policy fails. User gets no prompt; "Change how drive is unlocked at startup" asks for **admin username and password** | `close-out/04-C1-fleet-payload.txt`, `14-…png`, `15-C1-labuser-uac.png` |
| C-2a | + custom profile PIN Required, others Disallowed | Profile Verified, registry Required; TPM-only stays; same admin prompt for the user | `close-out/17-C2-after-profile.txt`, `19-C2-labuser-uac-required.png` |
| C-2b | + **Fleet script** adds TPM+PIN (random PIN, SYSTEM via fleetd) | Exit 0; protectors RecoveryPassword + TpmPin (TPM-only replaced). User now sees **"Change PIN" without an admin shield** | `close-out/20-C2-fleet-script-pin.txt`, `22-C2-labuser-after-pin.png` |
| C-3 | Fleet after refetch | Disk encryption **verified**; policy 588 "BitLocker startup PIN set (C:)" **fail → pass** | `close-out/21-C3-fleet-after-pin.txt` |

Lab note: BitLocker refused the TPM protector ("detected bootable media") until the two virtual CD drives were **disabled** inside
Windows; ejecting the media wasn't enough (`close-out/03-disable-cdrom.txt`).

Standard user, Fleet's own PIN setting, no Fleet Desktop: ![C-1 Manage BitLocker](test-evidence/close-out/14-C1-labuser-manage-bitlocker-front.png)

"Change how drive is unlocked at startup" needs admin credentials: ![C-1 UAC](test-evidence/close-out/15-C1-labuser-uac.png)

Same with the PIN-Required profile: ![C-2 UAC](test-evidence/close-out/19-C2-labuser-uac-required.png)

After the Fleet script added the PIN: "Change PIN" (no shield): ![C-2 after PIN](test-evidence/close-out/22-C2-labuser-after-pin.png)

### Fleet UI (close-out run, final state)
Fleet 7 → Controls → OS settings → Disk encryption → Windows: "Enable disk encryption" and "Require BitLocker PIN" on:
![Fleet 7 Windows disk encryption](test-evidence/close-out/fleet-ui/35-fleet7-windows-disk-encryption.png)

Fleet 7 → Configuration profiles: "C - BitLocker PIN required, others disallowed" (Windows):
![Fleet 7 profile](test-evidence/close-out/fleet-ui/34-fleet7-profile.png)

Host 16 → Controls: the profile and Disk encryption both **Verified**:
![Host 16 controls](test-evidence/close-out/fleet-ui/32-host16-controls-verified.png)

Host 16 → Policies: "BitLocker startup PIN set (C:)" **Pass**:
![Host 16 policy pass](test-evidence/close-out/fleet-ui/33-host16-policy-pass.png)

Host 16 → Details: disk encryption On, MDM On (manual), agent 1.61.0; activity "ran a script on this host" (the PIN script):
![Host 16 details](test-evidence/close-out/fleet-ui/30-host16-details.png)
![Host 16 activity](test-evidence/close-out/fleet-ui/31-host16-activity.png)

Note: the fleet 7 summary shows "Verified 3 hosts" while the fleet has one host (16); the count likely includes hosts deleted
earlier today. Not investigated.

## Standard user changing the PIN, and lockout (22:12–22:25)
| ID | What | Result | Evidence |
|---|---|---|---|
| D-1 | labuser opens "Change PIN" | Dialog opens **without UAC** (old/new PIN). "Reset a forgotten PIN" needs admin. Wrong old PIN rejected, no UAC; TPM counter unchanged. Full change not done (needs a known PIN) | `close-out/26`, `27`, `31`, `32` |
| L-1 | Profile H: ADMX_TPM legacy DA + standard-user thresholds 3 | Fleet **Verified**; registry set; after Tpm-Maintenance: **Max Auth Fail 32, heal 7200 s** (was 31, 600 s). No "3" | `close-out/34-L1-after-profile-H.txt`, `47`, `fleet-ui/36` |
| L-2 | Repeated wrong old PINs as labuser | After 4 rejected (5 incl. one earlier), Windows **disables PIN changes** until an admin resets; TPM counter still 0 | `close-out/41`–`46` |

"Change PIN" as a standard user opens without an admin prompt: ![Change startup PIN](test-evidence/close-out/26-D1-labuser-change-pin-click2.png)

"Reset a forgotten PIN" asks for admin credentials: ![UAC on reset](test-evidence/close-out/27-D1-labuser-reset-forgotten.png)

Wrong old PIN: ![Wrong PIN](test-evidence/close-out/31-D1-wrong-old-pin-result.png)

After repeated wrong PINs: ![PIN changes disabled](test-evidence/close-out/45-L2b-wrong-5.png)

Fleet host 16 Controls: profile H Verified: ![Profile H](test-evidence/close-out/fleet-ui/36-host16-controls-profile-H.jpg)

## Getting around the hardware (22:51–23:2x)
| ID | What | Result | Evidence |
|---|---|---|---|
| H-1 | VM platform signals | Desktop role, chassis 1, no Modern Standby: why "only USB" doesn't reproduce here | `hw-workaround/01-platform-signals.txt` |
| H-2 | Suspend BitLocker, reboot with boot menu on | Boots; **Windows Boot Manager draws** in UTM | `hw-workaround/02`, `03`, `06-reboot-boot-manager-menu.png` |
| H-3 | Fleet vs suspended BitLocker | Within ~20 min protection was back **On**: fleetd re-enables protection on encrypted, unprotected volumes (Fleet 4.93 `EnableBitLockerProtection`) | `RESULTS.md` 23:14 |
| H-4 | Pre-boot PIN screen (TPM+PIN, random PIN) | **Shown**: "Enter the PIN to unlock this drive"; typing works; Return must be sent as CR | `hw-workaround/21`–`25` |
| H-5 | Pre-boot wrong PINs | "Incorrect PIN; please enter the PIN again" x5; **the 6th wrong PIN -> BitLocker recovery** (recovery key needed) | `hw-workaround/25`–`27` |

Pre-boot PIN screen in UTM: ![PIN screen](test-evidence/hw-workaround/21-preboot-pin-screen.png)

Wrong PIN: ![Incorrect PIN](test-evidence/hw-workaround/25-preboot-wrong-pin-1.png)

After the 6th wrong PIN: recovery (only the key ID is shown): ![Recovery](test-evidence/hw-workaround/27-preboot-wrong-pin-6-recovery.png)

Windows Boot Manager drawn in UTM: ![Boot manager](test-evidence/hw-workaround/06-reboot-boot-manager-menu.png)
