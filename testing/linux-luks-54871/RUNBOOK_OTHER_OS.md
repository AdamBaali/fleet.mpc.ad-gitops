# Runbook: Fedora and Arch (prepared, not run)

Status 2026-10-16: images found, packages built, install files written. Nothing downloaded and no VM created yet. Run only when `testing/bitlocker-pin-42318/STATUS.md` says the Windows VMs are idle.

## What is ready
| Item | Fedora | Arch |
| --- | --- | --- |
| Image | Fedora 44 Server aarch64 netinst, 1.26 GB, sha256 `a93ebd03...262cc3` (official) | archboot aarch64 installer, about 0.5 GB (no official Arch ARM64 ISO exists; Arch Linux ARM is a rootfs tarball, no installer) |
| Download button | `Prep-Fedora-download.command` | `Prep-Arch-download.command` |
| Agent package | `vm/fedora/pkg/fleet-osquery-1.61.0.aarch64.rpm` (built, linked to the Linux LUKS Lab fleet) | `vm/arch/pkg/fleet-osquery-1.61.0-1-aarch64.pkg.tar.zst` (built) |
| VM definition | `vm/fedora/create-vm-fedora.applescript` (NVMe 25 GB, virtio-gpu-pci, 4 GB) | `vm/arch/create-vm-arch.applescript` |
| Unattended install | `tests/gen-fedora-ks.py <serve-dir>` writes a kickstart (LVM on LUKS2, GNOME, rpm, guest agent) from `.env` | to write at run time after checking whether archboot ships `archinstall` (A-2); fallback is a scripted manual install |
| Test scripts | `tests/q2-guest-any.sh` finds the LUKS device itself; the escrow trigger, `tools/boot-vm.sh`, `tools/unlock-watch.sh --live` are unchanged | same |

## Fedora run order (about 2 to 3 hours the first time)
1. Click `Prep-Fedora-download.command`. 2. Serve `vm/fedora/pkg/*.rpm` as `fleet-osquery.rpm` and the generated `ks.cfg` on `192.168.64.1:18080` (python http.server, bound to the bridge only, stopped afterwards). 3. `osascript vm/fedora/create-vm-fedora.applescript` (UTM stays running). 4. At the installer's GRUB menu press `e`, append ` inst.ks=http://192.168.64.1:18080/ks.cfg`, then Ctrl-X (scan codes `29,45,173,157`): these are plain text, no credentials. 5. It installs and ejects. 6. `tools/boot-vm.sh luks-fedora` (check the GRUB entries: the netinst ISO is ejected by `reboot --eject`, so this may not be needed), start `tools/unlock-watch.sh luks-fedora --live` yourself. 7. Rerun K-1 to K-7, M-2, M-5 with `tests/q2-guest-any.sh`, the escrow trigger and the screenshots.

What to compare on Fedora: dracut's unlock prompt text; the root detection when the layout is LVM on LUKS vs btrfs; zenity vs gnome dialogs; whether orbit finds the root device.

## Arch run order (about 3 to 5 hours)
1. Click `Prep-Arch-download.command`. 2. `osascript vm/arch/create-vm-arch.applescript`. 3. In the archboot console check for `archinstall`; configure LUKS2 on the root (no LVM, then a second run with LVM), `mkinitcpio` with `encrypt` or `sd-encrypt`, a desktop (GNOME or sway) and `zenity`. 4. Install the `pkg.tar.zst`, enroll. 5. Expect the escrow request to be refused or fail (Arch platforms are removed by PR #55070): record the exact server response, whether the Create key banner shows, and what orbit logs.

## Shared-Mac rules (same as before)
One 4 GB VM at a time, never while a Windows VM is running; disk above 20 GB free; never quit UTM; commit only my own paths in the GitOps repo; Adam starts the unlock watcher (it types the lab disk passphrase); screenshots from Claude's shell, not Adam's Terminal.
