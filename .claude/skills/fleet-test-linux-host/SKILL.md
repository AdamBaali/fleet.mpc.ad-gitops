---
name: fleet-test-linux-host
description: Get a Linux test host for a Fleet test (Docker sandbox or UTM VM for Ubuntu, Fedora, Arch), install fleetd, run commands in it, record ground truth, and test disk encryption (LUKS) and escrow. Use when a Fleet test needs a Linux host.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Linux test host

Task: $ARGUMENTS

Read `testing/_framework/guides/linux-hosts.md` now. It holds the commands, the display fixes, and the LUKS tricks.

Decide in this order:
1. Does the test need a reboot, a desktop, fleetd dialogs, or disk encryption? If no, use a Docker container
   (`testing/servicenow-itam-38864/scripts/run-sandbox-docker.sh`). It is the fastest and cleanest.
2. If yes, build a UTM VM (arm64, 4 GB, 4 cores, 25 GB). Ubuntu uses cloud-init autoinstall, Fedora a kickstart. Use ssh
   on Fedora, because SELinux confines the guest agent.
3. Install fleetd from a package built for that fleet (`fleetctl package --type=deb|rpm|pkg.tar.zst --arch=arm64`).
   The package holds the enroll secret: keep it out of git.
4. First evidence item: `hosts/host-facts.sh`.
5. Record what the host did with `servicenow-itam-38864/scripts/gt-lib.sh` and compare it with what Fleet reports.

Never screenshot installer pages that print secrets. Run one 4 GB VM at a time. Check Fleet's supported distro list before
you build an unusual one.
