---
name: fleet-test-windows-host
description: Build, boot, drive, enroll, and reset a Windows 11 arm64 test host on the Mac lab (Homebrew QEMU, UTM for the first install), run PowerShell in it, take screenshots, and handle BitLocker, TPM, sysprep, and provisioning packages. Use when a Fleet test needs a Windows host.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Windows test host

Task: $ARGUMENTS

Read `testing/_framework/guides/windows-hosts.md` and `testing/_framework/vm/README.md` now. They hold the commands.

Rules that decide the plan:
- Install Windows once in UTM from an answer ISO. Run every test host on Homebrew QEMU (`vm/qemu-boot.sh`) on an overlay
  of the base disk. UTM hangs after a reset or generalize.
- Run `sysprep /generalize /oobe /shutdown` in each clone before it enrolls in Fleet.
- Start QEMU as a long-lived background task with `FG=1`. Keep the Mac awake with `caffeinate -dims`.
- Run commands with `vm/qga.sh <vm> '<powershell>'`. After a reset the guest agent is gone: use Fleet scripts and live
  queries.
- Never power cycle during a reset. Use ramfb, not virtio-gpu, for any VM that generalizes.
- Needs a TPM (BitLocker): use UTM with its TPM, not QEMU.
- Build the MSI with `fleetctl package --type=msi`, one per fleet, and keep it and its secret out of git.
- First evidence item: `hosts/host-facts.ps1` through `qga.sh`.

Check which VMs and ports other sessions use with `testing/_framework/bin/status.sh` before you start one. Leave the lab
clean: list the VMs and overlays in `HANDOFF.md` under Teardown.
