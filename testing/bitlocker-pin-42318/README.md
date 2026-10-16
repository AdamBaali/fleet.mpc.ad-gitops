# BitLocker PIN on Windows: lab (fleetdm/fleet#42318)

Can Fleet give a customer an **enforced 6-digit BitLocker startup PIN on Windows, for non-admin users, without Fleet Desktop**?
Tested 2026-10-15/16 on Fleet 4.93.0 (`mdm.enable_custom_disk_encryption` on), fleet "Windows BitLocker Lab"
([`../../fleets/windows-bitlocker-lab.yml`](../../fleets/windows-bitlocker-lab.yml)), Windows 11 Pro 26H2 arm64 in UTM with TPM 2.0.

**Start with [EVIDENCE.md](EVIDENCE.md)**: every test, its result, screenshots and raw output. [LOG.md](LOG.md) is the full
chronological log, dead ends included.

## Results
- **No self-service PIN for standard users without Fleet Desktop.** Fleet's "Require BitLocker PIN" (and a PIN *Required*
  profile) doesn't prompt anyone; Manage BitLocker asks a standard user for admin credentials.
- **IT can set the PIN from Fleet**: a Fleet script adds TPM+PIN to an already-encrypted drive, Fleet reports Verified, and a
  policy finds hosts without a PIN. The user can then change the PIN without admin rights.
- **"Only USB is offered" = Windows treating the device as a slate.** Reproduced by making the VM report itself as a tablet;
  `SystemDrivesEnablePrebootInputProtectorsOnSlates`, sent as a Fleet profile, fixes it. Fleet doesn't send this node today.
- **Pre-boot:** the PIN screen works in UTM; the 6th wrong PIN in one boot forces BitLocker recovery. No setting gives "lock
  after 3"; the TPM lockout policy (deliverable by Fleet) only changes 31 -> 32 failures and slows the heal to 2 h.
- Fleet's payload itself works on a desktop-class device. Fleet 4.93's My device PIN form needs Fleet Desktop and fleetd 1.62.
- Side request fleetdm/fleet#27903: `manage-bde -w C:` works from a Fleet script; full encryption via `SystemDrivesEncryptionType`
  fails in fleetd 1.61.0 (wrong Encrypt flag); data drives weren't encrypted by `RequireDeviceEncryption` on a non-Entra host.

## Use it
| File | What |
|---|---|
| [`profiles/C - BitLocker PIN required, others disallowed.xml`](profiles/) | PIN Required, other methods Disallowed, 6 digits, enhanced PIN |
| [`profiles/D2 - BitLocker preboot input on slates only.xml`](profiles/) | The slates node alone: add it for devices that report "Slate" |
| [`profiles/H - 42318 TPM lockout ADMX.xml`](profiles/) | TPM lockout policy (tested; doesn't give 3; irreversible without a TPM clear) |
| [`tests/add-pin-random.ps1`](tests/add-pin-random.ps1) | Fleet script example: add TPM+PIN as SYSTEM (random PIN; replace with your own PIN process) |
| [`tests/platform-role.ps1`](tests/platform-role.ps1) | Fleet script: prints platform role (Slate?), model and the slates setting |
| Policy | `SELECT 1 FROM bitlocker_key_protectors WHERE drive_letter = 'C:' AND key_protector_type IN (4, 6);` (passes with a PIN) |

Profiles E–G are the fleetdm/fleet#27903 tests (see EVIDENCE.md).

## Reproduce
- VM: `vm/build-vm.sh` (UTM, unattended Windows 11 arm64, TPM 2.0); then install fleetd with `tools/build-windows-msi.sh`.
  Run PowerShell in the guest as SYSTEM: `tools/win-run.sh <vm> - < script.ps1`.
- Tablet ("slate") VM: QEMU 11.1.2 with [`vm/qemu-fadt-pm-profile.patch`](vm/qemu-fadt-pm-profile.patch) (ACPI FADT power profile
  from `QEMU_FADT_PM_PROFILE`; 8 = Tablet), run a disk clone with `vm/run-qemu-clone.sh 8`; control it with `vm/qmp.py`
  (screenshots, keys) and `vm/qga-cmd.py` (guest commands).

## Not verified
The customer's devices reporting "Slate"; TPM+PIN (rather than a startup password) on the slate VM; refetch stalls on physical
devices; a standard user completing a PIN change (dialog and lockout only).

No PINs, recovery keys or secrets are in this folder (screenshots show dots or the recovery key ID only). Customer notes and
unposted drafts are kept outside this repo.
