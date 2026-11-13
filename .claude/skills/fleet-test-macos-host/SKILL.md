---
name: fleet-test-macos-host
description: Test on a macOS host for Fleet: build and install the fleetd pkg, collect pmset and orbit logs for sleep and wake tests, record software ground truth, check report SQL without a Mac, and take window-only Terminal screenshots. Use when a Fleet test needs a Mac.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# macOS test host

Task: $ARGUMENTS

Read `testing/_framework/guides/macos-hosts.md` now.

- Sleep, lid, battery, and Power Nap tests need real hardware. A VM can't show them. Read logs through Fleet scripts run
  as root.
- Build the pkg with `fleetctl package --type=pkg --enable-scripts --fleet-desktop`. `--enable-scripts` is required for
  script tests. The secret comes from `.env` or the Fleet API, never from a committed file.
- Evidence for sleep: `pmset -g log` and `/var/log/orbit/orbit.stderr.log` for the same time window, lined up by time
  (`testing/power-nap-46924/scripts/collect.sh`).
- Check report SQL without a Mac with `testing/mac-readiness/tools/sqlite-logic-check.py`, then run it on a real Mac.
- Screenshots: window only (`macterm.sh`, `winid`, `screencapture -l`), masked with `maskbox`.
- First evidence item: `hosts/host-facts.sh`.
