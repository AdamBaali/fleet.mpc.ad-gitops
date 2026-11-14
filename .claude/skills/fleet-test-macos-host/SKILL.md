---
name: fleet-test-macos-host
description: Test on a Mac for Fleet: build and install the fleetd pkg, collect pmset and orbit logs, record software ground truth, and take window-only screenshots. Use when a Fleet test needs a Mac.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# macOS test host

Task: $ARGUMENTS

Read `testing/_framework/guides/macos-hosts.md`. Sleep and battery tests need real hardware, with logs read through Fleet
scripts. Build the pkg with `--enable-scripts` for script tests. Screenshots are window only and masked. First evidence
item: `hosts/host-facts.sh`.
