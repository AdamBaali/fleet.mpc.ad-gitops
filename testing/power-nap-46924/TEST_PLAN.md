# Test plan: macOS Power Nap and policy automations

Issue: https://github.com/fleetdm/fleet/issues/46924 · Story: https://github.com/fleetdm/fleet/issues/48898 · Started: 2026-10-19

## Scope
What fleetd does with a software install or script run from a policy automation while a Mac laptop sleeps with the lid closed. Product asked for fleetd logs for both installs and scripts (2026-07-07). The issue thread (a community member, 2026-10-06) says downloads start in a DarkWake, the Mac sleeps 2 to 5 seconds later, and the connection is dead at the next DarkWake about 16 minutes on.

Not in scope: changing fleetd. This collects evidence and checks the reported mechanism.

## Environment
| Item | Value |
|---|---|
| Fleet | Lab Fleet (version at run time), fleet "Power Nap Lab" (`fleets/power-nap-lab.yml`) |
| Host | One MacBook Air, current macOS, fleetd from stable. Real hardware: a VM doesn't do Power Nap or clamshell sleep |
| Installers | Stored on the Fleet server. fleetd downloads from Fleet only |
| Logs | `/var/log/orbit/orbit.stderr.log`, `pmset -g log`, `pmset -g assertions`, Fleet activities and host details |
| Lab differences from production | One host, not 125. No presigned download URLs. Lab network, not corporate Wi-Fi |

## Tests
| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| D-1 | Desk: fleetd code | Read `orbit/pkg/installer` and search orbit for sleep assertions | Downloads have no sleep assertion. Fallback goes to Fleet right after a URL failure | Code lines quoted in the result |
| B-1 | Baseline power settings | `pmset -g`, `pmset -g custom`, `sysctl hw.model`, fleetd version | Power Nap, tcpkeepalive and standby values recorded | Values saved |
| C-1 | Control: install, lid open, on power | Policy fails, automation installs a large pkg (for example Google Chrome) | Install succeeds | Fleet activity "installed" |
| PN-1 | Large install, lid closed, battery | Delete Google Chrome, close the lid on battery at once, leave it overnight. Policies run about hourly, so the install starts at the first policy run after the lid closes | Download fails across DarkWakes, as reported | orbit log errors line up with `pmset -g log` DarkWake and sleep times, Fleet shows "Software installer download failed" |
| PN-2 | Small install, lid closed, battery | Same as PN-1 with a small pkg (for example swiftDialog) | Unknown: may finish inside one DarkWake | Outcome recorded with timings |
| PN-3 | Script, lid closed, battery | Policy automation runs a script that sleeps 120 s and writes a timestamp each 10 s | Script stops when the Mac sleeps, or runs across wakes | Timestamps and Fleet's script result recorded |
| PN-4 | Lid closed on power | PN-1 with the charger connected | Unknown: wakes may last longer | Outcome recorded |
| PN-5 | Power Nap off | `sudo pmset -b powernap 0`, repeat PN-1 | Unknown: tcpkeepalive wakes may still run fleetd | Whether fleetd runs at all, from the orbit log |
| PN-6 | What happens next | After PN-1, open the lid and wait | Unknown: does the policy automation retry, and when | Next attempt time and result recorded |
| PN-7 | Workaround idea: caffeinate | Run `caffeinate -s` for the length of an install from a script, repeat PN-1 | Download finishes | Only if PN-1 fails. A test of the mechanism, not a product fix |

## Out of scope / not tested
- Presigned URL downloads (the customer's setup). The thread says the fallback to Fleet dies the same way, and PN-1 tests the Fleet download.
- Intel Macs and older macOS versions.
- Fleet-maintained app installs outside policy automations (Self-service, setup experience). Setup experience already holds `caffeinate` for swiftDialog (D-1).
