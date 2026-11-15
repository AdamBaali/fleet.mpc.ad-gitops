---
name: fleet-test-windows-host
description: Boot, drive, enroll, and reset a Windows 11 arm64 test host on the Mac lab (QEMU, UTM for the first install), run PowerShell in it, and take screenshots. Use when a Fleet test needs a Windows host.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Windows test host

Task: $ARGUMENTS

Read `testing/_framework/guides/windows-hosts.md` and `testing/_framework/vm/README.md`. Key rules: run hosts on QEMU, not
UTM; start QEMU with `FG=1` in a background task; `sysprep` each clone before enrolling; never power cycle during a reset;
BitLocker needs UTM's TPM. First evidence item: `hosts/host-facts.ps1` through `vm/qga.sh`. Check
`testing/_framework/bin/status.sh` before starting a VM, and list VMs to delete in `HANDOFF.md`.
