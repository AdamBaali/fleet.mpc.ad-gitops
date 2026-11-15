# macOS hosts

Sleep, lid, battery, and Power Nap need real hardware: a VM can't show them. Read logs through Fleet scripts run as root.

- Facts: `hosts/host-facts.sh`.
- Package: `fleetctl package --type=pkg --enable-scripts --fleet-desktop ...` (`--enable-scripts` is required for script tests). Example: `testing/power-nap-46924/scripts/build-pkg.sh` (the fleet ID is hard-coded).
- Sleep evidence: `pmset -g log` and `/var/log/orbit/orbit.stderr.log` (root only) for the same window, lined up by time. orbit uses `T` in timestamps where pmset uses a space. `testing/power-nap-46924/scripts/collect.sh baseline|window <ID> "<YYYY-MM-DD HH:MM>"`.
- Software ground truth: `testing/servicenow-itam-38864/scripts/gt-macos.sh dmg-install|pkg-install|fma-wait|open|uninstall`. Pick apps from a company publisher.
- Report SQL without a Mac: `testing/mac-readiness/tools/sqlite-logic-check.py`. Then run it on a real Mac.
- Screenshots: `tools/macterm.sh <out.png> <scriptfile>` for terminal output, `winid "<App>"` with `screencapture -x -o -l<id>` for apps. Window only. Mask with `maskbox`.
- Long runs: `caffeinate -dims`. Check `bin/status.sh` first on the shared Mac.
