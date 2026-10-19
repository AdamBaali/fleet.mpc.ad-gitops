# Notes: software fields for ServiceNow ITAM (#38864)

## What each OS can give
Built-in means Fleet's software inventory has it today. Report means one of the custom reports in `lib/<platform>/reports/software-itam.reports.yml`. Every report query was checked against the osquery 5.14.1 table specs. The Linux queries ran clean in an Ubuntu container (837 DEB packages, every one found its dpkg file list).

| Field | macOS | Windows | Linux RPM | Linux DEB |
|---|---|---|---|---|
| Name, version | Built-in | Built-in | Built-in | Built-in |
| Publisher | Report: `signature.authority` (code signing certificate name) | Built-in as `vendor` in the API, not in the UI. Report: `programs.publisher` | Built-in as `vendor`. Report: `rpm_packages.vendor` | Report: `deb_packages.maintainer` (a person or list, not a company) |
| Install location | Built-in (`installed_paths`) | Report: `programs.install_location` (often empty) | None | None |
| First installed | Report: `kMDItemDateAdded` (mdls), bundle `btime`, pkg `install_time`. All proxies. M-1 and M-2 pick one | Report: `programs.install_date` (registry, day only, sometimes empty) | Report: `rpm_packages.install_time` | Report: dpkg file list mtime. This is last changed, not first installed |
| Last run | Built-in (`last_opened_at`, from Spotlight) | Report: Prefetch `last_run_time`, UserAssist `last_execution_time` (per exe, not per program) | None | None |

## Fallback for any OS: first seen
Where no install date exists, the exporter can record the first time it sees an app on a host and keep that date. It is honest only if labeled "first seen". Apps installed before the exporter started all get the start date. #54912 proposes the same thing inside Fleet.

## Exporter design (after the tests)
An hourly job, for example a scheduled GitHub Action or a ServiceNow scheduled import:
1. `GET /api/v1/fleet/hosts`, filtered to the fleet, for host ID, serial number and hostname. The serial number is the join key ServiceNow already uses for hardware.
2. `GET /api/v1/fleet/hosts/:id/software` for name, version, source, vendor, `installed_paths` and `last_opened_at`.
3. Each report's stored results through the API. Check the endpoint name on the lab version, since queries were renamed to reports.
4. Join per host on app path (macOS) or name and version (Windows, Linux).
5. POST rows to a ServiceNow Import Set staging table. A transform map writes them into `cmdb_sam_sw_install` and matches the host by serial number.

## Field map (draft, confirm in E-1)
| ServiceNow (`cmdb_sam_sw_install`) | Fleet source |
|---|---|
| Installed on | Host, matched by serial number |
| Display name, version | Software name, version |
| Publisher | macOS `authority`, Windows `publisher`, RPM `vendor`, DEB `maintainer` |
| Install date | macOS and Windows and RPM report value, else first seen |
| Last used | macOS `last_opened_at`, Windows Prefetch or UserAssist, else empty |

## Risks
- **Report row cap.** Fleet stores a limited number of rows per report (`query_report_cap`, 1000 by default) across all hosts. A fleet of Macs with 100 apps each passes that at 10 hosts. Options: raise the cap, send report results to a log destination and read them there, or run the query live per host. A-2 measures it.
- **Proxy dates.** An auditor may treat a proxy as a fact. Label each date with its source in ServiceNow.
- **Windows last run is per exe.** Prefetch and UserAssist name executables, not programs. Matching uses `install_location`, which many installers leave empty.
- **No last run on Linux.** File access times are not reliable (`relatime`, `noatime`).

## Lab versus production
Four lab hosts against a full fleet. A new ServiceNow developer instance has no existing hardware rows, so E-1 creates its own host record first.
