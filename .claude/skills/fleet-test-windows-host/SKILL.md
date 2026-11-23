---
name: fleet-test-windows-host
description: Install, boot, drive, enroll, and reset a Windows 11 arm64 test host on the Mac lab (Homebrew QEMU), run PowerShell in it, and take screenshots. Use when a Fleet test needs a Windows host.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Windows test host

Task: $ARGUMENTS

Read `testing/_framework/guides/windows-hosts.md` and `testing/_framework/vm/README.md`, including "macOS 27 and Claude
Code". Then check, before planning anything:

1. The base disk exists: `ls ~/Documents/fleet-lab/base/`. If it's missing, plan a fresh install with
   `vm/qemu-install.sh` (about an hour, plus an 8.5 GB ISO download).
2. Tools are installed: `qemu-system-aarch64`, `tesseract`, and Pillow for `python3`.
3. Nothing else is running: `testing/_framework/bin/status.sh`.

Key rules:
- Run everything on Homebrew QEMU. On macOS 27, Claude Code can't open UTM's folder, and Full Disk Access on Claude.app
  doesn't change that. Keep disks and ISOs in `~/Documents/fleet-lab/`.
- Keep `VM_ROOT` at its default (`~/Documents/fleet-lab/vm`). Deeper paths break QEMU's 104-byte socket limit.
- Run VM commands with the sandbox off. Start QEMU with `FG=1` in a background task.
- `sysprep /generalize` each clone before enrolling. Never power cycle during a reset. BitLocker needs UTM's TPM, which
  only a person can drive now.
- Wait for screens with `screen.sh <vm> wait` (local OCR), not repeated screenshots.
- Before typing into a new terminal-panel tab, make sure no oh-my-zsh update prompt is pending.

First evidence item: `hosts/host-facts.ps1` through `vm/qga.sh`. List VMs and disks to delete in `HANDOFF.md`.
