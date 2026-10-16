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

## 2026-10-15 progress
- **S-1d PASS:** unattended Ubuntu 24.04.5 install (server ISO, LVM on LUKS), VM `luks-ubuntu`. Boots from the encrypted disk without anyone at the console: Adam runs `tools/unlock-watch.sh`, which types the passphrase after each boot. Guest agent works, so tests run through `tools/vm-run.sh`.
- **S-1c FAIL:** desktop autoinstall crashed after 28 min. Ubuntu desktop live needs `virtio-gpu-pci` (black on `virtio-ramfb`).
- **S-3 PASS:** baseline `luksDump`: LUKS2, one keyslot (0, argon2id), no tokens. Next: Fleet escrow (S-4 to S-6), then Q2 (M-*), then Q1 (K-*).
- Finding: with the installer ISO still attached the VM boots the installer; pick "Boot from next volume" in GRUB (UTM scripting can't eject).

## 2026-10-16 final results
- **Q1:** removing the end user's slot (with the escrow key) locks the user out: the old passphrase is rejected at boot (K-3). The escrow key boots the host (K-4). Every cold restart waits at the unlock prompt (K-5): no TPM token, key file or crypttab keyscript on this install (K-6). Fleet does not notice the removal (K-7). A saved LUKS header restores the removed key (K-11, K-12). Removing Fleet's own slot makes Fleet show action required (K-9).
- **Q2:** escrow, add, change, kill and remove keyslot never changed the UUID, the master key digest or the data (S-6, M-2); only `reencrypt` or `luksFormat` did (M-5).
- **Q3:** not supported (D-1). No live Arch VM.
- **The real dialog and banner** were captured (G). Findings: the dialog needs an unlocked, visible desktop; after a timed-out request a new one returns 409 for minutes; orbit's key add took about 4 minutes the first time and over 15 minutes while the host was busy (argon2).
- **Not done:** Fedora VM, Arch VM, TPM-backed layouts.
- **Lab mistakes recorded:** a watcher typed a key into GRUB's command line (part of a lab-only key appeared on a screen; that slot was removed); a restore script deleted the only key file (recovered from a header backup, K-12).

## 2026-10-16 Fedora 44 VM (same questions as Ubuntu): PASS
Evidence: `test-evidence/fedora/` (F-1 environment, F-2 escrow slot, F-3 keyslot changes, F-4 user slot removed + two reboots). Runner: `tests/run-fedora.sh`.
- **Escrow works on Fedora.** Fleet added key slot 1 (the escrowed key opens only slot 1) and showed Verified. It took about 14 minutes (Ubuntu: 4) while this Mac was busy.
- **Q2:** UUID, master key digest and data hash stayed the same through luksAddKey, luksChangeKey, luksKillSlot and luksRemoveKey. Only `cryptsetup reencrypt` and a new `luksFormat` changed the digest (scratch device).
- **Q1:** with the user's slot removed, the old passphrase is rejected, the escrow key unlocks the disk, and each of two reboots waited at the unlock prompt until the key was typed (SSH answered about 2 s after the watcher typed it). Fleet still showed Verified.
- **Deviations, in order of impact:** the installer's GRUB ignored letter keys (kickstart delivered on an OEMDRV disk); the display stays "not active" after GRUB unless the kernel has `nomodeset` (still blank, so no console screenshots for Fedora); SELinux set to permissive so the guest agent works (tests run over SSH); the first kickstart had an empty user-password hash (macOS openssl has no `-6`) and two installs were thrown away; fleetd was installed by hand after the kickstart download failed.
- **Test-script bugs found and fixed first:** `sudo` closes the file descriptor behind `<(...)` (a user-passphrase check wrongly said "no"); `wc -l` padding broke the F-2 verdict; the scratch `reencrypt` control needs `--key-slot 0`. Each is recorded in the result files.
- **Not done on Fedora:** the real passphrase dialog and Fleet Desktop banner (blank display), TPM-backed layouts, Arch.
