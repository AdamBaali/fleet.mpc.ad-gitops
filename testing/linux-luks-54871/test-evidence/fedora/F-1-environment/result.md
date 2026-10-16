# F-1: Fedora VM environment

- **Date:** 2026-10-16
- **Objective:** Record the Fedora VM so a reader can recreate it.
- **Expected:** Fedora Server 44 aarch64 with root on LVM inside LUKS2, fleetd enrolled in the Linux LUKS Lab fleet.

## Steps and evidence
- `01-guest.txt`: release, kernel, cryptsetup, fleetd, disk layout, SELinux mode.
- `02-luksdump-masked.txt`: `cryptsetup luksDump` with salts masked and the digest shortened.

## Deviations (logged, not hidden)
- Fedora Server netinst with a kickstart (`tests/gen-fedora-ks.py`): text mode, `autopart --type=lvm --encrypted`, GNOME workstation package set, autologin so the escrow dialog has a desktop.
- The GRUB menu of the installer ignored letter keys, so the kickstart came from a disk labelled OEMDRV, not `inst.ks=`.
- Kernel options `nomodeset console=tty0 console=ttyAMA0`: without them the VM display stayed "not active" after GRUB. The screen is still blank, so no screenshots of the Fedora console.
- `selinux --permissive`: with SELinux enforcing, the QEMU guest agent is confined and cannot write files or manage services, so tests run over SSH (key installed by the kickstart).
- The kickstart's download of the fleetd rpm failed (curl 52); it was installed by hand with `dnf install`.
- The first two installs failed to give a usable login (empty password hash from macOS openssl) and a first boot with no usable display; both were reinstalled.

## Result: INFO
