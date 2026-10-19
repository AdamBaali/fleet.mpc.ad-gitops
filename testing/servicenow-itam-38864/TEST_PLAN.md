# Test plan: software fields for a Fleet to ServiceNow ITAM export

Issue: https://github.com/fleetdm/fleet/issues/38864 · Gaps: #54912 (install date), #54914 (publisher) · Started: 2026-10-19 · Run: 2026-10-20

## Scope
A stopgap until Fleet exports to ServiceNow itself. The ask: installed software on each host in ServiceNow, macOS required, and for each app when it was first installed and when it last ran. The export runs hourly.

Fleet already returns name, version, install path and last opened through its software API (see NOTES.md, "What Fleet already returns"). It returns no install date and no publisher. This plan tests the built-in last opened values, whether native osquery reports fill the two gaps on each OS, how accurate each source is, and whether all of it can be pulled through the API every hour.

Not in scope: building the exporter. That comes after this plan shows which fields are trustworthy. See NOTES.md for the exporter design.

## Environment
| Item | Value |
|---|---|
| Fleet | Lab Fleet, 4.93.0 or later (report cap and paginated report API), fleet "ServiceNow ITAM Lab" (`fleets/servicenow-itam-lab.yml`) |
| Reports | `lib/macos/reports/software-itam.reports.yml` (3), `lib/windows/reports/software-itam.reports.yml` (1), `lib/linux/reports/software-itam.reports.yml` (2). Native osquery tables, hourly, snapshot. No scripts |
| Report cap | `report_cap: 10000` in `default.yml` for this lab |
| Hosts | One Mac (real hardware, Spotlight on), one Windows 11 VM (Prefetch on), one Fedora host (RPM), one Ubuntu host (DEB) |
| ServiceNow | Optional: a free personal developer instance from developer.servicenow.com, for E-1 only |
| Lab differences from production | Four hosts, not thousands. No MDM-wide app deployment. A new developer instance has no SAM plugin data |

## Ground truth
Every date test needs a known time. For each test app, write down the install time and launch time (`date -u` on macOS and Linux, `Get-Date -AsUTC` on Windows) in RESULTS.md before reading Fleet. Compare Fleet's value to that record. A value within 2 minutes matches.

## Tests
| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| S-1 | Setup | 1. Check the Fleet version (4.93.0 or later). 2. Add repository secret `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET`. 3. Merge, let the apply run. 4. Enroll one host per OS. 5. Record each host's osquery version (`SELECT version FROM osquery_info`). 6. Run each report as a live report | Six reports in the fleet. Each returns rows on its platform with no SQL error | Rows on each host. osquery versions recorded |
| M-1 | macOS install date, three ways | Install one app each way at a recorded time: drag from a DMG, a pkg, and a Fleet-maintained app. Read `date_added`, `bundle_created` and the receipt `install_time` | `date_added` matches all three. `bundle_created` may keep the DMG's original time. Receipt only for the pkg | One source matches the recorded time for all three |
| M-2 | macOS install date after an update | Update the M-1 apps (or install an older version, then a newer one). Read the same columns | `bundle_created` and `date_added` may move to the update time | Recorded whether each column keeps the first install or moves. Decides the "first installed" or "last changed" label |
| M-3 | macOS last opened (built-in) | Open each M-1 app at a recorded time. Read `last_opened_at` from `GET /api/v1/fleet/hosts/:id/software`. Repeat after M-2 | Matches within one software refresh. Empty after an update until opened again (API docs) | Matches the recorded time. Post-update behavior recorded |
| M-4 | macOS publisher | Read `authority` and `team_identifier` for a Developer ID app, an App Store app, an Apple app and an unsigned app | Developer ID name for the first, Apple names for the next two, no row or empty authority for the last | Publisher readable for signed apps. Rows per app counted (universal apps may return one per architecture) |
| M-5 | macOS cost | After two hourly runs, read each report's performance in Fleet (CPU and memory) on a Mac with 100 or more apps | `signature` and `mdls` reports stay under the watchdog limits | No report denylisted. Times recorded |
| W-1 | Windows install date coverage | 1. Install an MSI app and an EXE app at recorded times. 2. Read `install_date` for all programs. 3. Count empty values | Both test apps match the recorded date. Some older programs are empty | Test apps match. Empty count recorded |
| W-2 | Windows last opened (built-in) | 1. Check `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters\EnablePrefetcher`. 2. Start each W-1 app at a recorded time. 3. Read `last_opened_at` from the software API | Matches for programs with an install location. Empty for programs without one | Times match. Programs with an empty `installed_paths` counted |
| W-3 | Windows publisher | Read `publisher` from the report for the W-1 apps. Confirm the software API has no `vendor` field | Report has the publisher. API doesn't | Publisher present for both W-1 apps |
| L-1 | RPM install date and vendor | Install a package at a recorded time (`rpm-ostree install` on atomic, `dnf install` otherwise). Reboot if atomic. Read the RPM report | `install_time` matches. On atomic, it may show the deployment build time | Recorded which time each host type shows |
| L-2 | DEB install date | 1. Install a package at a recorded time. Read `list_changed`. 2. Upgrade it. Read again | Matches the install time, then moves to the upgrade time | Behavior recorded. Label in ServiceNow decided (last changed) |
| L-3 | Linux last opened (built-in) | 1. Record mount options for `/` and `/usr` (`findmnt`). 2. Run an L-1 and an L-2 package's binary at a recorded time. 3. Read `last_opened_at` from the software API | RPM matches unless `noatime`. DEB empty if osquery is older than 5.19 | Recorded per host with the osquery version and mount options |
| A-1 | API pull | Script: list hosts in the fleet, get each host's software, get each report's results. Join on the keys in NOTES.md | Every field in NOTES.md "Field map" comes back for each host | One JSON file per host with all fields |
| A-2 | Report cap | 1. Count rows per report (`count` in `GET /api/v1/fleet/reports/:id/report`). 2. Check the report isn't clipped. 3. Work out rows for 2000 Macs from the Mac's row count | Lab under 10000, nothing clipped. Production estimate far over any stored cap | Lab counts recorded. Production transport decided (log destination or raised cap) |
| A-3 | Freshness | Install, open and remove an app. Time how long each change takes to show in the API | Software inventory updates on its own interval. Reports update hourly | Worst case delay recorded. Must fit an hourly export |
| E-1 | ServiceNow load (optional) | Post the A-1 output for one host to an Import Set staging table on a developer instance, transform it into the Software Installation table (`cmdb_sam_sw_install`) | Rows show name, version, publisher, install date and last used per host | One host's software visible in ServiceNow |

## Out of scope / not tested
- ChromeOS, iOS, iPadOS and Android. Fleet's inventory there is limited (Chrome extensions, managed apps) and no install date or publisher source exists.
- Hardware fields. Most hardware is already in ServiceNow.
- A production-scale run. A-2 estimates the scale problem from numbers instead.
- Windows Server, where Prefetch is off by default.
