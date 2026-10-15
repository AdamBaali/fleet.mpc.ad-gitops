# S-1d: Ubuntu 24.04.5 server ISO, unattended autoinstall (LVM on LUKS), VM `luks-ubuntu`

- **Date:** 2026-10-15
- **Objective:** A working encrypted Ubuntu VM with no one at the keyboard.
- **Expected:** Installs unattended, powers off, boots from the encrypted disk.

## Steps and evidence
- VM created by UTM scripting only (NVMe 25 GB, virtio-gpu-pci, virtio-net-pci). cloud-init finds `user-data` over HTTP through the DMI serial. The installer applies it and asks "Continue with autoinstall? (yes|no)".
- Screenshots of the config, install logs and the autoinstall question were not kept (they show config text or only scrolling logs).
- `first-boot-after-unlock.png`: after the install powered off, the VM started from the installer ISO again (a CD stays attached); the installer's language screen. Fixed by picking "Boot from next volume" in GRUB (two Down keys, Return).
- After that the guest booted from the encrypted disk and answers over the guest agent: `hostname` luks-ubuntu, root on `ubuntu--vg-ubuntu--lv` inside `dm_crypt-0` inside `nvme0n1p3` (crypto_LUKS), orbit active. The disk passphrase was typed by `tools/unlock-watch.sh`, which Adam started.

## Result: PASS

Deviations from the end user guide: automated install, not the "Use LVM and encryption" page (same result: LUKS2 on LVM). Finding: a returning boot goes back to the installer while its ISO is attached; UTM scripting can't eject it, so each boot needs "Boot from next volume".
