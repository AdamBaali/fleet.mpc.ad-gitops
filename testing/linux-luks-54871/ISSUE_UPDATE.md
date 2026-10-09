# Issue update for fleetdm/fleet#54871 (DRAFT, for Adam to review and post, never auto-posted)

Status as of 2026-10-09. Desk work is done. The VM tests are not finished.

**3. Does Fleet support key escrow on Arch Linux? Not today.**
- The docs list Ubuntu, Kubuntu and Fedora.
- The server's `IsLUKSSupported` also accepts `arch`, `archarm`, `manjaro`, `manjaro-arm`, `cachyos` and `omarchy`, but open PR #55070 removes them. Its description says no user could complete escrow on them.
- #55069 tracks Omarchy and lists why escrow fails there: dialogs don't open on Wayland (`XDG_RUNTIME_DIR`), zenity and kdialog aren't installed, and the root device lookup breaks on btrfs subvolumes.
- Not yet shown on a live Arch VM.

**1. Removing the end user's key:** not tested yet. What the code does: orbit only **adds** a keyslot (random passphrase) and never removes or edits the user's slot. The Ubuntu installer says "You will be prompted for your passphrase every time you turn on your computer." Both still need a real reboot test with the escrow key as the only slot.

**2. Does LUKS invalidate any key:** not tested yet. Expected: adding, changing or removing a keyslot re-wraps the master key and leaves it unchanged. To be shown with `cryptsetup luksDump` before and after (master key digest and UUID).

**Done so far:** Ubuntu 24.04.5 installed by following the end user guide (Use LVM and encryption), with a screenshot of every page. Two small doc differences: the installer option is "Use LVM and encryption" (the guide says "with"), and an installer update screen appears. Blocked: the VM's display stays black after the first reboot.

Evidence: `testing/linux-luks-54871/EVIDENCE.md` in the lab GitOps repo.
