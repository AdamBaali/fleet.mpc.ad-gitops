---
name: fleet-test-linux-host
description: Get a Linux test host for a Fleet test (Docker or UTM VM), install fleetd, run commands, and record ground truth. Use when a Fleet test needs a Linux host.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Linux test host

Task: $ARGUMENTS

Read `testing/_framework/guides/linux-hosts.md`. Use a Docker container unless the test needs a reboot, a desktop, or fleetd
dialogs. Otherwise build an arm64 UTM VM. Install fleetd from a package built for that fleet and keep it out of git. First
evidence item: `hosts/host-facts.sh`. Record what the host did with `gt-lib.sh` and compare it with Fleet.
