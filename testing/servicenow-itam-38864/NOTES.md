# Notes: software fields for ServiceNow ITAM (#38864)

## How this was checked
Against Fleet `main` at 4.93.0 (2026-10-08), following the Fleet repo's own GitOps skill (`.claude/skills/fleet-gitops`):
- Fleet's software ingestion: `server/service/osquery_utils/queries.go` (`softwareMacOS`, `softwareWindows`, `softwareLinux` and the override queries).
- The host software API: `docs/REST API/rest-api.md`, "Get host's software".
- fleetd tables: `orbit/pkg/table/`.
- Every report table and column: Fleet's osquery schema (`schema/osquery_fleet_schema.json`, through the skill's `validate.py --table`).
- The report cap: `CHANGELOG.md` 4.93.0, `server/fleet/app.go`, `docs/Configuration/yaml-files.md`.

The Linux report SQL ran clean in osquery 5.14.1 in Ubuntu and Fedora containers (see RESULTS.md). The macOS and Windows SQL has not run on a host yet. S-1 does that.

## What Fleet already returns
`GET /api/v1/fleet/hosts/:id/software` already gives these, so the reports don't collect them again:

| Field | macOS | Windows | Linux |
|---|---|---|---|
| Name, version, source | Yes | Yes | Yes |
| Install path | `installed_paths` | `installed_paths` (from `install_location`, often empty) | No |
| Last opened | `last_opened_at` from `apps.last_opened_time`. Empty after an update until the app is opened again | `last_opened_at` from Prefetch, matched to the program by install path | `last_opened_at` from file access times of the package's executables. RPM always. DEB needs osquery 5.19 or later (`deb_package_files`) |
| Team ID | `signature_information.team_identifier` (fleetd `codesign`) | No | No |

Fleet reads `programs.publisher` and `rpm_packages.vendor` into the software `vendor` field, but the host software API doesn't return it. Fleet doesn't read any install date.

## Why native tables, not fleetd tables
No fleetd table has an install date or a publisher name for the apps we need. `codesign` returns only the team ID and the code directory hash, and Fleet already ingests both. `fleetd_pacman_packages` has an install date, but only for Arch Linux. Native osquery tables cover every gap. No scripts and nothing installed: every field comes from a report.

## What the reports add
| Field | macOS | Windows | Linux RPM | Linux DEB |
|---|---|---|---|---|
| Publisher | `signature.authority` (signing certificate name) | `programs.publisher` | `rpm_packages.vendor` | `deb_packages.maintainer` (a person or list, not a company) |
| First installed | `kMDItemDateAdded` (`mdls`), bundle `btime` (`file`), pkg `install_time` (`package_receipts`). All proxies. M-1 and M-2 pick one | `programs.install_date` (registry, day only, sometimes empty) | `rpm_packages.install_time` | dpkg file list `mtime` (`file`). Last changed, not first installed |

Join keys back to the software API: macOS on app path (`installed_paths`), Windows and Linux on name and version.

## Why no extension
An osquery extension (`software_itam`) was built and tested on 2026-10-19 and 2026-10-20, then dropped to keep the stopgap simple. Reports need nothing installed, reviewed or pinned on hosts, and they go away with a YAML delete when Fleet ships #54912 and #54914.

What that gives up, and how the export covers it:
- **First install that survives upgrades.** The extension read macOS `InstallHistory.plist` and `dpkg.log`. Reports read Spotlight date added, bundle creation, RPM install time and the dpkg file list time, which can move on an upgrade or reinstall. The exporter's own `first_seen` column keeps the first sighting instead. It starts on the exporter's first run.
- **App Store publisher on macOS.** Apple re-signs App Store apps, so the native publisher is empty for them. The Team ID stays available in Fleet's `signature_information`.

## Sandbox findings (2026-10-20)
Ubuntu 24.04 and Fedora 41 containers, real package manager, osquery shell mode, no Fleet server (see RESULTS.md):
- **DEB.** `list_changed` moves to every upgrade and reinstall. It is a last changed date. Label it that way.
- **RPM.** `install_time` moves to every upgrade, downgrade and reinstall. It is the install time of the version on disk.
- On both, the exporter's `first_seen` is the only date that stays at the first sighting.

## Report cap
Fleet stores at most `report_cap` results per report (default 1000). Since 4.93.0 Fleet raises that to the host count when the host count is higher, so a report with one row per host is never clipped. These reports return one row per app or package, so the cap still applies. When a report is full, Fleet keeps updating hosts already in it and skips new hosts. A host result over 512 KB isn't stored.

Lab: a Fedora Workstation host has about 2000 RPM packages, so `default.yml` sets `report_cap: 10000` for this lab.

Production: rows are about hosts times apps. 2000 Macs with 150 apps each is 300,000 rows in one report. Options, in order of preference:
1. Set `automations_enabled: true` on the reports and read them from the log destination. Nothing is capped.
2. Raise `report_cap`. Fleet's docs recommend one report at a time while watching the database.
3. Read per host with `GET /api/v1/fleet/hosts/:id/reports/:report_id`. Still capped, since storage is the limit.

## First seen
The exporter records the first time it sees each app on each host and keeps that date in its state file (`--state`). It goes to ServiceNow as its own `first_seen` column next to `install_date`, and as the install date when no OS source exists. Apps installed before the exporter's first run all get that run's date. #54912 proposes the same thing inside Fleet. Keep the state file between runs, or every app looks new.

## Exporter
`scripts/fleet_itam_export.py` is the prototype, Python standard library only. Without `--post` it sends nothing. It does what an hourly job would do, for example a scheduled GitHub Action or a ServiceNow scheduled import:
1. `GET /api/v1/fleet/hosts`, filtered to the fleet, for host ID, serial number and hostname. ServiceNow already matches hardware on serial number.
2. `GET /api/v1/fleet/hosts/:id/software` for name, version, source, `installed_paths` and `last_opened_at`.
3. `GET /api/v1/fleet/reports` to find the ITAM reports by name, then `GET /api/v1/fleet/reports/:id/report` for each. Since 4.93.0 it takes `page` and `per_page`.
4. Join per host on the keys above. Windows install dates also join the uninstall key report on `identifying_number`.
5. Keep only the sources the issue covers (`apps`, `programs`, `rpm_packages`, `deb_packages`).
6. With `--post`, POST rows to a ServiceNow Import Set staging table (`insertMultiple`). A transform map writes them into `cmdb_sam_sw_install` and matches the host by serial number.

## Field map (draft, confirm in E-1)
| ServiceNow (`cmdb_sam_sw_install`) | Fleet source |
|---|---|
| Installed on | Host, matched by serial number |
| Display name, version | Software API name, version |
| Publisher | The native report column for the OS. Source in `publisher_source` |
| Install date | Native (Windows InstallDate, uninstall key time, RPM install time, Spotlight date added, dpkg list time, bundle created), else exporter first seen. Source in `install_date_source` |
| First seen | Exporter state file. First time the exporter saw the app on the host |
| Last used | Software API `last_opened_at`. Source in `last_used_source` |
| Install location | Software API `installed_paths` |

The order puts real install records before proxies. M-1, W-1, L-1 and L-2 may change it.

## Risks
- **Proxy dates.** An auditor may treat a proxy as a fact. Label each date with its source in ServiceNow.
- **Windows last opened is per install path.** Programs with an empty `install_location` get no last opened date.
- **Linux last opened depends on mount options.** `noatime` stops it, and `relatime` updates it at most once a day.
- **macOS signature cost.** Fleet keeps its own `codesign` query separate from the main software query for performance. M-5 checks the `signature` report on a host with many apps.
- **Moving install dates on Linux.** Upgrades and reinstalls move both the RPM and DEB dates. Send `first_seen` with every row so auditors have a fixed date.
- **Lost state file.** If the exporter's state file is lost, every `first_seen` resets to the next run.

## Lab versus production
Four lab hosts against a full fleet. A new ServiceNow developer instance has no existing hardware rows, so E-1 creates its own host record first.
