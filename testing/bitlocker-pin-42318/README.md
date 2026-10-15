# BitLocker PIN lab (Windows BitLocker Lab fleet)

Tests run on 2026-10-15 for the BitLocker PIN customer request (Fleet issue 42318) and a side request about full-disk vs
used-space encryption (Fleet issue 27903). Fleet 4.93.0 with `FLEET_MDM_ENABLE_CUSTOM_DISK_ENCRYPTION=true`, fleet
"Windows BitLocker Lab" (`../../fleets/windows-bitlocker-lab.yml`), Windows 11 Pro 26H2 arm64 VM in UTM with TPM 2.0.

Start at [EVIDENCE.md](EVIDENCE.md) (every test, its result and its evidence), then [RESULTS.md](RESULTS.md) (running log).

## Results
- On a desktop-class device (not Modern Standby), Fleet's own "Require BitLocker PIN" payload shows "Enter a PIN" in Manage
  BitLocker, and an admin can add a PIN to an already encrypted drive.
- A custom profile with PIN Required (other startup methods Disallowed) works next to Fleet's own encryption and key escrow, but
  doesn't prompt anyone; a standard user is asked for admin credentials. With an admin-set PIN, Fleet reports Verified.
- Fleet policy `SELECT 1 FROM bitlocker_key_protectors WHERE drive_letter = 'C:' AND key_protector_type IN (4, 6);` fails on a
  host without a PIN.
- The pre-boot PIN screen can't be tested in UTM (Windows Boot Manager never draws it); needs real hardware.
- Side request: `manage-bde -w C:` wipes free space on a used-space drive; full encryption via `SystemDrivesEncryptionType` = 1
  fails in fleetd 1.61.0 (wrong Encrypt flag); data drives weren't encrypted by `RequireDeviceEncryption` on a non-Entra host.

## Layout
`TEST_PLAN.md`, `RESULTS.md`, `EVIDENCE.md`, `NOTES.md` (open items) · `profiles/` custom BitLocker profiles tested ·
`tests/` PowerShell checks run in the guest · `vm/` unattended VM build (`build-vm.sh`, `detach-isos.sh`) · `tools/` helpers
(`win-run.sh` runs PowerShell in the guest through UTM's guest agent) · `test-evidence/` raw output and window-only screenshots
(no PINs, no recovery keys; the My device address bar is masked).

Not published here: customer-requirement notes and draft replies (internal).
