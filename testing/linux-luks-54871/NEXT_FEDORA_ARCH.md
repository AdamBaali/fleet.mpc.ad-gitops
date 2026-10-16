# Later: Fedora and Arch (not done; optional for closing #54871)

Why optional: Q1 and Q2 are `cryptsetup` behaviour (same on every distro) and the Arch answer is settled from the docs, the code and PRs #55070 and #55069. These runs would show distro-specific boot and escrow details.

## Constraints (shared Mac)
- The BitLocker session runs Windows VMs and plans a standalone QEMU clone (4 GB). Never run Windows and a new Linux install at the same time: keep to one 4 GB VM, free disk above 20 GB, no UTM quit or restart. Check `testing/*/STATUS.md` first and update mine.
- Argon2 key derivation crawled (over 15 minutes) when the Mac was busy: do the escrow step when the other session is idle.

## Fedora (about 2 to 3 hours hands-on, 30 minutes to rerun the tests)
1. Download Fedora Server or Workstation aarch64 ISO (about 2.2 GB, sha256 check) with Adam's yes.
2. VM like luks-ubuntu: NVMe 25 GB, `virtio-gpu-pci`, `virtio-net-pci`, 4 GB, 4 cores. Unattended with a kickstart over HTTP (`inst.ks=http://192.168.64.1:18080/ks.cfg`; encrypted `autopart --encrypted`, no typing).
3. Package: `fleetctl package --type=rpm --arch=arm64 --fleet-desktop` for a new "Linux LUKS Lab" enroll.
4. Reuse `tests/q2-guest.sh`, the escrow trigger, `tools/boot-vm.sh` (Fedora GRUB differs: check the menu entries), `tools/unlock-watch.sh --live`.
5. Differences to record: dracut prompt text, default layout (btrfs, no LVM: check Fleet's root detection), zenity vs kdialog.

## Arch (about 3 to 5 hours)
1. Find an aarch64 image first: Arch Linux ARM (no ISO; rootfs tarball), or archboot aarch64 ISO. A1 in the test plan.
2. `archinstall` with a config (LUKS2 root, systemd-boot or GRUB) or a scripted manual install.
3. `fleetctl package --type=pkg.tar.zst --arch=arm64`; install `cryptsetup`, `zenity`.
4. Expect the escrow flow to fail (platform `arch`/`archarm`): record where (server side, dialog on Wayland, root detection). Compare with #55070 and #55069.
