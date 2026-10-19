# Test plan: software fields for a Fleet to ServiceNow ITAM export

Issue: https://github.com/fleetdm/fleet/issues/38864 · Gaps: #54912 (install date), #54914 (publisher) · Started: 2026-10-19 · Run: 2026-10-20

## Scope
A stopgap until Fleet exports to ServiceNow itself. The ask: installed software on each host in ServiceNow, macOS required, and for each app when it was first installed and when it last ran. The export runs hourly.

Fleet's software inventory already has name, version and source on every platform, and last opened on macOS. It has no install date anywhere and no publisher on macOS. This plan tests whether custom reports fill those gaps on each OS, how accurate each source is, and whether the results can be pulled through the API every hour.

Not in scope: building the exporter. That comes after this plan shows which fields are trustworthy. See NOTES.md for the exporter design.

## Environment
| Item | Value |
|---|---|
| Fleet | Lab Fleet (version at run time), fleet "ServiceNow ITAM Lab" (`fleets/servicenow-itam-lab.yml`) |
| Reports | `lib/macos/reports/software-itam.reports.yml`, `lib/windows/reports/software-itam.reports.yml`, `lib/linux/reports/software-itam.reports.yml`. All hourly, snapshot |
| Hosts | One Mac (real hardware, Spotlight on), one Windows 11 VM (Prefetch on), one Fedora host (RPM), one Ubuntu host or container (DEB) |
| ServiceNow | Optional: a free personal developer instance from developer.servicenow.com, for E-1 only |
| Lab differences from production | Four hosts, not thousands. No MDM-wide app deployment. A new developer instance has no SAM plugin data |

## Ground truth
Every date test needs a known time. For each test app, write down the install time and launch time (`date -u` on macOS and Linux, `Get-Date -AsUTC` on Windows) in RESULTS.md before reading Fleet. Compare Fleet's value to that record. A value within 2 minutes matches.

## Tests
| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| S-1 | Setup | 1. Add repository secret `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET`. 2. Push, let the apply run. 3. Enroll one host per OS into the fleet. 4. Wait for the first hourly run, or run each report as a live report | Six reports appear in the fleet. Each host returns rows for its platform | Reports listed in Fleet, rows on each host |
| M-1 | macOS install date, three ways | Install one app each way at a recorded time: drag from a DMG, a pkg, and a Fleet-maintained app. Read `bundle_created`, `date_added` and `package_receipts.install_time` | `date_added` matches all three. `bundle_created` may keep the DMG's original time. Receipt only for the pkg | One source matches the recorded time for all three |
| M-2 | macOS install date after an update | Update the M-1 apps (or install an older version, then a newer one). Read the same columns | `bundle_created` and `date_added` may reset to the update time | Recorded whether each column keeps the first install or moves. Decides "first installed" vs "last changed" label |
| M-3 | macOS last opened | Open each M-1 app at a recorded time. Read `last_opened` in the report and `last_opened_at` in `GET /api/v1/fleet/hosts/:id/software` | Both match within one report interval. Spotlight may lag | Both values match the recorded time |
| M-4 | macOS publisher | Read `authority` and `team_identifier` for a Developer ID app, an App Store app, an Apple app and an unsigned app | Developer ID name for the first, Apple names for the next two, `signed = 0` for the last | Publisher readable for signed apps. Rows per app counted (universal apps may return one per architecture) |
| M-5 | macOS cost | After two hourly runs, read each report's performance in Fleet (CPU and memory) on a Mac with 100 or more apps | `signature` and `mdls` reports stay under the watchdog limits | No report denylisted. Times recorded |
| W-1 | Windows install date coverage | 1. Install an MSI app and an EXE app at recorded times. 2. Read `install_date` for all programs. 3. Count empty values | Both test apps match the recorded date. Some older programs are empty | Test apps match. Empty count recorded |
| W-2 | Windows last run | 1. Check `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters\EnablePrefetcher`. 2. Start each W-1 app from the Start menu at a recorded time. 3. Read Prefetch and UserAssist reports | Both show the exe with the recorded time | Time matches. Note which exe names map to which program |
| W-3 | Windows publisher | Compare `programs.publisher` to the software `vendor` in the Fleet API for the same apps | Same value | Values match for every W-1 app |
| L-1 | RPM install date and vendor | Install a package at a recorded time (`rpm-ostree install` on atomic, `dnf install` otherwise). Reboot if atomic. Read the RPM report | `install_time` matches. On atomic, it may show the deployment build time | Recorded which time each host type shows |
| L-2 | DEB install date | 1. Install a package at a recorded time. Read `list_changed`. 2. Upgrade it. Read again | Matches the install time, then moves to the upgrade time | Behavior recorded. Label in ServiceNow decided (last changed) |
| L-3 | Linux last run | Read `last_opened_at` from the Fleet API for the L-1 and L-2 packages | Empty. No reliable source on Linux | Recorded. Gap stays open |
| A-1 | API pull | Script: list hosts in the fleet, get each host's software, get each report's results. Join on host ID and app path or name | Every field in NOTES.md "Field map" comes back for each host | One JSON file per host with all fields |
| A-2 | Report row cap | Read `server_settings.query_report_cap` in the Fleet config. Compare it to the expected rows (apps per host times hosts) | Lab is under the cap. Production fleets with hundreds of hosts are over it | Recorded. Decides whether the exporter reads stored reports or a log destination |
| A-3 | Freshness | Install, open and remove an app. Time how long each change takes to show in the API | Software inventory updates on its own interval. Reports update hourly | Worst case delay recorded. Must fit an hourly export |
| E-1 | ServiceNow load (optional) | Post the A-1 output for one host to an Import Set staging table on a developer instance, transform it into the Software Installation table (`cmdb_sam_sw_install`) | Rows show name, version, publisher, install date and last used per host | One host's software visible in ServiceNow |

## Out of scope / not tested
- ChromeOS, iOS, iPadOS and Android. Fleet's inventory there is limited (Chrome extensions, managed apps) and no install date or publisher source exists.
- Hardware fields. Most hardware is already in ServiceNow.
- A production-scale run. A-2 estimates the scale problem from numbers instead.
- Windows Server, where Prefetch is off by default.
