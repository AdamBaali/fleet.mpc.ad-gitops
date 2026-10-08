# Results: fleetdm/fleet#54871 (Linux and LUKS)

## Phase 0: what Fleet claims (docs and code, fleet/ cloned 2026-10-08)

### Docs
- `articles/enforce-disk-encryption.md`: Linux key escrow is "Ubuntu, Kubuntu, and Fedora". Linux disk encryption
  "requires end user interaction". Fleet adds a NEW LUKS keyslot with a random passphrase; "the original passphrase
  remains active". Nothing says what happens if the user's keyslot is removed.
- `articles/linux-disk-encryption-end-user.md`: same distro list, LUKS2 only, no escrow on hosts with multiple
  user accounts. Does not mention Arch.
- GitOps: `controls.linux_settings.enable_escrow_disk_encryption_key` (`docs/Configuration/yaml-files.md`).
  There is no Linux "enforce encryption" setting, only escrow.

### Code
- `server/fleet/hosts.go` `IsLUKSSupported()`: platform `ubuntu`, `zorin`, Fedora (via OS version), and also
  `arch`, `archarm`, `manjaro`, `manjaro-arm`, `cachyos`, `omarchy`. So the SERVER treats Arch as supported while the
  DOCS do not list it. (Q3: needs a real test.)
- `orbit/pkg/luks/luks_linux.go`: needs `cryptsetup`, plus `zenity` or `kdialog` for the passphrase prompt (fatal if
  neither). Root device found with `lsblk` (`orbit/pkg/lvm`). Escrow path: validate the user passphrase against ANY
  slot, pick the next free slot (max 8), `AddKey` with a random 35-char passphrase, verify it, send it with the slot
  number and salt. If sending fails, the slot is removed. Cipher assumed `aes-xts-plain64`.
- Ubuntu 26 TPM-backed FDE (snapd) uses a separate recovery-key path via the snapd socket.
- Fleet only ADDS a keyslot. Nothing in orbit removes or changes the user's slot, and the master (volume) key is
  never touched by `luksAddKey`.

### What this means for the three questions (to be proven on VMs)
1. User slot removed: with the escrow slot as the only slot, boot asks for a passphrase the user doesn't have.
   Expected yes, unless a TPM or keyfile token also unlocks. Test.
2. LUKS doesn't invalidate keys: expected true. `luksAddKey`, `luksRemoveKey` and `luksChangeKey` re-wrap the
   master key and leave it unchanged. Prove with `luksDump` (compare `MK digest`). Note: `luksDump --dump-volume-key`
   would print the key, so do NOT use it.
3. Arch: server allows it. Orbit on Arch is untested. Test.

## Phase 1: lab setup
- GitOps repo (local commit only, NOT pushed): `fleets/linux-luks-lab.yml` ("Linux LUKS Lab", Linux escrow on) and
  the `FLEET_LINUX_LUKS_LAB_ENROLL_SECRET` line in `.github/workflows/workflow.yml`.
- Waiting on: Adam pushes, and the repo secret `FLEET_LINUX_LUKS_LAB_ENROLL_SECRET` exists.

## Phase 1 progress (2026-10-08)
- GitOps pushed by Adam. Run succeeded. Fleet "Linux LUKS Lab" (ID 5) exists, Linux escrow on. Premium confirmed by Adam.
- Deviation: the old cloud-image VM has an unencrypted root, so a new VM `luks-ubuntu` is built from the Ubuntu
  24.04.5 live-server arm64 ISO (sha256 verified, 3.8 GB) with autoinstall: LVM on LUKS, `ubuntu-desktop-minimal`,
  `zenity`, fleetd deb with the lab enroll secret. Seed ISO and passphrases live in `vm/` and `.env` (gitignored).
- Deviation: `qemu-img` in UTM is a library, not a binary, so UTM creates the disk.

## S-1: Ubuntu desktop installer, "Use LVM and encryption" (2026-10-08): PASS
Installed Ubuntu 24.04.5 (arm64 desktop) in UTM by following the end user guide. Screens: `test-evidence/ubuntu/S-1-installer/`.
- Deviation: the guide text says "Use LVM with encryption", the installer option is "Use LVM and encryption".
- Deviation: the installer offered an installer update ("Update available"). Skipped. The guide doesn't mention it.
- The passphrase page says "You will be prompted for your passphrase every time you turn on your computer." Useful for Q1.
- The "Review your choices" page shows "Disk encryption: LUKS (LVM)".
- The timezone page didn't appear as a separate step in this run.

## S-8: first boot after install: BLOCKED
Black screen "Display output is not active" on every start. See HANDOFF.md.
