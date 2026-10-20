# Test plan: host and software fields for a Fleet to ServiceNow ITAM export

Issue: https://github.com/fleetdm/fleet/issues/38864 · Gaps: #54912 (install date), #54914 (publisher) · Started: 2026-10-19 · Run: 2026-10-20

## Scope
A stopgap until Fleet exports to ServiceNow itself. The issue asks for installed software on each host in ServiceNow, macOS required, with when each app was first installed and when it last ran, refreshed hourly. It also lists the host fields ServiceNow needs. This plan tests every field in that list on macOS, Windows and Linux.

Two collection paths, nothing installed on hosts beyond fleetd:
1. **Built-in.** Fleet's host and software APIs (name, version, install path, last opened, host fields).
2. **Native reports.** osquery reports with built-in tables (`lib/<os>/reports/software-itam.reports.yml`) for install date and publisher.

The exporter prototype (`scripts/fleet_itam_export.py`) joins both and is itself under test (A and E tests). It also keeps its own first seen date per app, the only date that doesn't move on an upgrade or reinstall on Linux.

An osquery extension path (`software_itam`) was dropped on 2026-10-20 to keep the stopgap simple: nothing to install, review or pin on hosts. Its X and C tests are removed. Git history keeps them.

## Environment
| Item | Value |
|---|---|
| Fleet | Lab Fleet, 4.93.0 or later (report cap, paginated report API), fleet "ServiceNow ITAM Lab" (`fleets/servicenow-itam-lab.yml`) |
| Native reports | macOS 3, Windows 2, Linux 2. Hourly, snapshot |
| Report cap | `report_cap: 10000` in `default.yml` for this lab |
| Hosts | One Mac (real hardware, Spotlight on, signed in to the App Store), one Windows 11 VM (Prefetch on), one Fedora host (RPM, Workstation or atomic), one Ubuntu host (DEB) |
| IdP | The lab's IdP with SCIM, so H-5 has a user and department on at least one host |
| ServiceNow | Optional: a personal developer instance, for E-1 and E-2 only |
| Lab differences from production | Four hosts, not thousands. No MDM-wide app deployment. A new developer instance has no SAM data |

## Ground truth
Every date test needs a known time. The `scripts/gt-*` helpers do each action (install, open, upgrade, uninstall, reinstall) and append its UTC time to `ground-truth/<host>.tsv` at the moment it happens, before anyone reads Fleet. `scripts/compare.py` checks the exporter output against that file.

Match rule: within 2 minutes. Sources that hold only a day (Windows `InstallDate`) match when the day is within one day, since the registry stores the host's local day. An install started from Fleet or the App Store is recorded when the app arrives on disk.

## How to run
| Script | Where | What it covers |
|---|---|---|
| `scripts/gt-macos.sh`, `gt-linux.sh`, `gt-windows.ps1` | On each test host, as root or elevated | Ground truth for M, W, L, U-1, U-4 |
| `scripts/host-local-check.sh`, `.ps1` | On each test host | On-host rows and timings for S-1, M-5 |
| `scripts/run-api-tests.sh` | Any machine that reaches Fleet | S-1, H-1 to H-6, A-1 to A-3, U-1, and runs `compare.py` |
| `scripts/fleet_itam_export.py` | Any machine | A-1, A-4, E-1, E-2 |
| `scripts/compare.py` | Any machine | Verdicts for every ground truth event |

Unit tests for the Python and the API runner: `cd scripts && python3 -m unittest discover -s tests` (fake Fleet API, no network).

"Runner" in the tables: **script** runs and writes a verdict on its own, **script + manual** needs a person to act (click Install in Fleet, reboot) between steps, **manual** is read and judged by a person.

## Setup
| ID | Test | Steps | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| S-1 | Setup | 1. Check the Fleet version (4.93.0 or later). 2. Add repository secret `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET`. 3. Merge, let the apply run. 4. Enroll one host per OS. 5. `run-api-tests.sh setup <fleet_id>`. 6. `host-local-check` on each host | Seven ITAM reports in the fleet. Hosts of all three OSes. Every native report returns rows on its OS with no SQL error | Script verdict PASS and no stderr in the local check | script |

## Host fields (issue list)
Run all with `run-api-tests.sh hosts <fleet_id>`. Each is checked on every host in the fleet. PARTIAL names the hosts with an empty value.

| ID | Field | Source | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| H-1 | Host name | `display_name`, else `hostname` | Set on all hosts | Present on all hosts | script |
| H-2 | OS and OS version | `platform`, `os_version` | Set on all hosts | Present on all hosts | script |
| H-3 | Serial number | `hardware_serial` | Set on the Mac and physical hosts. Often empty on VMs (issue footnote) | Present on physical hosts. Empty only on VMs, recorded | script |
| H-4 | Manufacturer and model | `hardware_vendor`, `hardware_model` | Set on all hosts. Apple returns an identifier such as `Mac15,9`, not a marketing name | Present on all hosts. Apple format recorded | script |
| H-5 | Assigned user and department | `end_users[0].idp_username`, `idp_department` (List hosts with `populate_end_users`) | Set where the IdP maps a user to the host | Present on every host with an IdP user. Usernames are not written to evidence | script |
| H-6 | Last seen | `seen_time` | Set on all hosts, within the check-in interval for online hosts | Present on all hosts | script |

## macOS software
| ID | Test | Steps | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| M-1 | Install date, every install method | `gt-macos.sh dmg-install`, `pkg-install`, `fma-wait` (click Install in Fleet), then the hourly run. `run-api-tests.sh export`, then `compare.py` | `date_added` matches all methods. `bundle_created` may keep the DMG's original time. Receipt only for the pkg | One native source matches for every method. compare.py lists the matching candidates | script + manual |
| M-2 | Install date after an upgrade | `gt-macos.sh dmg-upgrade`, `pkg-upgrade`. Next run, export, compare | Native dates may move to the upgrade time | compare.py PASS (keeps first install) or PARTIAL (moved). Decides the label | script |
| M-3 | Last used (built-in) | `gt-macos.sh open`. Next software refresh, export, compare. Repeat after M-2 | `last_opened_at` matches. Empty after an upgrade until opened again (API docs) | compare.py PASS for each app. Post-upgrade behavior recorded | script |
| M-4 | Publisher, native | `gt-macos.sh unsigned-install`, `appstore-wait`. Export, compare. Read the publisher report for a Developer ID app, an Apple app, an App Store app and the unsigned app | Developer ID name, "Apple", empty for the App Store app (Apple re-signs it), empty for unsigned | Matches the expected publisher in the ground truth file | script |
| M-5 | Cost, native | `host-local-check.sh` on a Mac with 100 or more apps. After two hourly runs, read each report's performance in Fleet | `signature` and `mdls` reports stay under the watchdog limits | No report denylisted. Seconds and CPU recorded | script + manual |

## Windows software
| ID | Test | Steps | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| W-1 | Install date coverage | `gt-windows.ps1 -Action msi-install`, `-Action exe-install`. Export, compare. Count programs with an empty `install_date` in the report | Both test programs match the recorded day. Some older programs are empty | compare.py PASS for both. Empty count recorded | script |
| W-2 | Last used (built-in) | `gt-windows.ps1 -Action facts` (Prefetch on), `-Action open`. Next refresh, export, compare | Matches for programs with an install location. Empty for programs without one | compare.py PASS for programs with an install path. Programs with empty `installed_paths` counted | script |
| W-3 | Publisher | Export. Check the W-1 programs' publisher and that the software API has no `vendor` field | Report has the publisher. API doesn't | Publisher present for both programs | script |
| W-4 | Uninstall key write time | Export. For programs with an empty `install_date`, read `native:registry_key_written` in the candidates. After `gt-windows.ps1 -Action msi-upgrade`, check whether it moved | The key time is near the install time. An upgrade rewrites it | Fills every empty `install_date`. Upgrade behavior recorded | script + manual |

## Linux software
| ID | Test | Steps | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| L-1 | RPM install date and vendor | On Fedora: `gt-linux.sh install`. Export, compare | `install_time` matches. On atomic hosts, live-applied layers may show the deployment time | compare.py PASS, or the atomic behavior recorded. After an upgrade or reinstall `install_time` moves (sandbox run), so `first_seen` carries the first sighting | script |
| L-2 | DEB install date | On Ubuntu: `gt-linux.sh install`, then `upgrade`. Export, compare after each | `list_changed` matches the install, then moves to the upgrade time | Behavior recorded. Label decided (last changed). Exporter `first_seen` stays at the first sighting | script |
| L-3 | Last used (built-in) | `gt-linux.sh facts` (osquery version, mount options), `gt-linux.sh open`. Next refresh, export, compare | RPM matches unless `noatime`. DEB empty below osquery 5.19 | Result recorded per host with osquery version and mount options | script |

## Uninstall
| ID | Test | Steps | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| U-1 | Software API drops removed software | `gt-<os> uninstall`, then `run-api-tests.sh watch <fleet_id> <host_id> <name> absent` | Gone at the next software refresh | Gone within 60 minutes | script |
| U-2 | Reports drop removed software | After U-1, wait for the next hourly run. Export and check the native report rows for the host | Gone at the next report run | Gone within 60 minutes | script |
| U-3 | Export drops the row | Export after U-1, compare | No row for the removed app | compare.py PASS for the uninstall event | script |
| U-4 | Reinstall | `gt-<os> reinstall` after U-1. Next run, export, compare | `install_date` moves to the reinstall on every native source. `first_seen` keeps the first sighting while the exporter state file is kept | Behavior recorded per OS. `first_seen` unchanged | script |

## Export and API
| ID | Test | Steps | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| A-1 | Pull and join | `run-api-tests.sh export <fleet_id>` | One JSON per host with the host fields and every software row, each date with its source | Host files written. Field coverage recorded per OS | script |
| A-2 | Report cap | `run-api-tests.sh report-cap <fleet_id>` | Lab under 10000, nothing clipped. Estimate for 2000 Macs recorded | No ITAM report clipped | script |
| A-3 | Freshness | Install an app, then `run-api-tests.sh watch <fleet_id> <host_id> <name> present`. Check the report by export after the next hourly run | Software refresh and the hourly report both inside 60 minutes | Both within 60 minutes | script |
| A-4 | Hourly rerun | Run the exporter twice an hour apart with the same state file | Same rows, no duplicates, `first_seen` unchanged | Row count stable. No key appears twice | script + manual |
| A-5 | Host offline | Shut a host down for two report intervals. Export. Start it. Export again | Stored rows stay with their old `last_fetched`, then refresh | Export never drops an offline host's software. Refresh within one interval of coming back | script + manual |

## ServiceNow
| ID | Test | Steps | Expected | Pass when | Runner |
|---|---|---|---|---|---|
| E-1 | Load (optional) | Create import set table `u_fleet_sw_install` and a transform map to `cmdb_sam_sw_install` that coalesces on serial, name and version. `fleet_itam_export.py --post --snow-instance <id>` | One host's software in ServiceNow with publisher, install date and its source, first seen, last used | Rows visible on the host's record | script + manual |
| E-2 | Reload (optional) | Run E-1 again | Rows update, no duplicates | Row count unchanged | script + manual |

## Out of scope / not tested
- ChromeOS, iOS, iPadOS and Android. The issue marks their software inventory partial (Chrome extensions, managed apps) and no install date or publisher source exists.
- Windows Server, where Prefetch is off by default.
- A production-scale run. A-2 estimates the scale problem from numbers.
- Report results through a log destination. NOTES.md names it as the production path. The lab uses stored results.
