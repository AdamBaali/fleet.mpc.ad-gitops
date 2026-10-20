# Power Nap Lab

Purpose: test what fleetd does with policy automations (software installs and scripts) while a Mac laptop sleeps with the lid closed. Issue: https://github.com/fleetdm/fleet/issues/46924. Owner: Adam. Tests and results: `testing/power-nap-46924/`.

Host: one MacBook Air.

| Policy | Fails when | Automation |
| --- | --- | --- |
| Power Nap test - Google Chrome installed | Google Chrome is deleted | Install Google Chrome (large download) |
| Power Nap test - swiftDialog installed | `/Library/Application Support/Dialog` is deleted | Install swiftDialog (small download) |
| Power Nap test - script flag file absent | `/var/tmp/fleet-pn-script` exists | Run `lib/macos/scripts/power-nap-timestamps.sh` |

Reports `Power Nap test - pmset settings` and `Power Nap test - power source` (`lib/macos/reports/power-nap.reports.yml`) record the power settings and power source for B-1 and each run.

Enroll secret: repository secret `FLEET_POWER_NAP_LAB_ENROLL_SECRET` (set). Get the package from Fleet > Hosts > Add hosts.
