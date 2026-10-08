# VM plan for #54871 (what Fleet supports, what to build)
Researched 2026-10-08 across issues, PRs, code and docs. No Figma designs are linked from any of these stories.

## What "supported" means today
| Source | Distros |
| --- | --- |
| Docs (`enforce-disk-encryption.md`, end user guide) | Ubuntu, Kubuntu, Fedora. Zorin isn't in the docs |
| Code in this lab's clone (`IsLUKSSupported`) and Fleet 4.92 | Ubuntu, Zorin, Fedora, **and** Arch, Arch ARM, Manjaro, Manjaro ARM, CachyOS, Omarchy |
| Open PR #55070 (closes #49059), reverts the Arch family | **Ubuntu, Zorin, Fedora only** (`fleet.LUKSSupportedPlatforms`). Its text: Arch family and Omarchy were added by platform-recognition changes, got an escrow status and could be told to escrow, "No user could complete escrow on them" |
| Issue #55069 (open), Omarchy | 4.91.0 release notes said escrow worked on Omarchy. A 2026-10-07 VM test found it doesn't (below) |

Q3 answer from this: **No, Fleet doesn't support key escrow on Arch.** The server accepted it by accident, and PR #55070 removes it.
We still run it once on a real Arch VM to show where it breaks.

Omarchy findings from #55069 (useful for Arch too):
- fleetd launches dialogs without `XDG_RUNTIME_DIR` on Wayland, so zenity fails with "Failed to open display".
- Omarchy ships neither zenity nor kdialog, and the escrow error doesn't say what to install.
- The verify query reads lsblk's single `mountpoint`. Btrfs with several subvolumes on one LUKS device breaks it.
- Omarchy 4+ reports `platform=omarchy`, 3 and earlier report `arch`.

## Known limits from other stories (not in the three questions, mention in the doc edit if they matter)
#47256 multi-disk LVM+LUKS escrow fails. #35070 headless servers. #24167 no encryption without reinstall.
#28765 Cinnamon dialogs. #42895 ZFS encryption status. #49059 Pop!_OS (`platform=pop`, like ubuntu) not counted.
#54422 and #52320 NixOS in progress. #52236 (closed): escrowed key changed or removed should show a banner and "Action
required (pending)". The customer in that bug "tested both changing and completely nuking the slot". We re-test it (K-9).
Ubuntu 26 TPM-backed FDE uses a separate snapd recovery-key path (not in scope).

## VMs to build (all arm64 on UTM, QEMU backend, 4 GB RAM, 4 cores, 25 GB disk)
| # | VM | Why | Installer step that matters |
| --- | --- | --- | --- |
| 1 | Ubuntu 24.04 desktop | Docs-supported. Q1 and Q2 | Advanced features > Use LVM and encryption |
| 2 | Fedora Workstation (current release) | Docs-supported, different initramfs (dracut). Repeats Q1 and Q2 | Installation destination > Encrypt my data |
| 3 | Arch Linux ARM or archboot, LUKS2 root | Q3, expected unsupported | archinstall with disk encryption |
| 4 (optional) | Ubuntu 26.04 desktop | Latest LTS. Shows whether the installer offers TPM FDE and which path Fleet takes | Whatever the installer offers |
Build and test one VM at a time. Delete the previous disk first: the Mac has about 2.5 GB free, one VM needs about 10 GB.

## Simple way for Adam to create a VM in UTM
1. UTM > Create a New Virtual Machine > **Virtualize** > **Linux**.
2. Boot ISO Image: choose the installer ISO. Leave "Use Apple Virtualization" OFF.
3. Memory 4096 MB, 4 CPU cores, storage 25 GB. Skip shared directory. Name it `luks-ubuntu`, `luks-fedora`, `luks-arch`.
4. Save, then Claude drives the installer from here (screenshots, clicks). Adam types the passphrase and the account
   password, and ejects the ISO when the installer asks.
Use the wizard rather than my AppleScript. The AppleScript-built VMs are what ended up with the black display.

## ISOs (download needs Adam's yes each time)
Ubuntu 24.04.5 desktop arm64 (4.0 GB, sha256 `2be09ca8...bd14` from cdimage.ubuntu.com). Fedora Workstation aarch64 live ISO
(about 2.2 GB). Arch: no official arm64 ISO, use Arch Linux ARM or archboot aarch64 (check at the time).
