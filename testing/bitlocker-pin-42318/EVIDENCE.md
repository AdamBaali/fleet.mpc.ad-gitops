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
| N-3 | Lockout after 3 failed PIN attempts | NOT-RUN / not researched | — |

Screenshots never show a PIN (dots only) or a recovery key; My device screenshots have the address bar (device token) masked.
