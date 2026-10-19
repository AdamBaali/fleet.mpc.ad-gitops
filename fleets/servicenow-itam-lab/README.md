# ServiceNow ITAM Lab

Purpose: test which software fields Fleet can export to ServiceNow ITAM on each OS (fleetdm/fleet#38864). Tests and results: `testing/servicenow-itam-38864/`.

Hosts: one Mac, one Windows 11 VM, one Fedora host, one Ubuntu host.

Two collection paths run side by side, so the tests can compare them field by field.

## Native reports (no extension)
| Report file | Fills |
| --- | --- |
| `lib/macos/reports/software-itam.reports.yml` | Install date candidates, publisher from code signing, pkg receipts |
| `lib/windows/reports/software-itam.reports.yml` | Install date and publisher from Programs, Uninstall key write time |
| `lib/linux/reports/software-itam.reports.yml` | RPM install time and vendor, DEB last changed and maintainer |

## software_itam extension
| File | Role |
| --- | --- |
| `lib/all/reports/software-itam-extension.reports.yml` | `SELECT * FROM software_itam`, one row per app or package |
| `lib/<os>/policies/software-itam-extension.policies.yml` | Fails when the table isn't registered, then runs the installer |
| `lib/<os>/scripts/install-software-itam-extension.*` | Downloads the binary pinned by commit and SHA-256, adds it to osquery's default `extensions.load`, restarts fleetd 30 seconds later |

Source: `software_itam/` in AdamBaali/fleet-extensions. To ship a new build, update the commit and SHA-256 values at the top of the three installers.

The installers use osquery's default autoload file (`/var/osquery/extensions.load` on macOS, `/etc/osquery/extensions.load` on Linux, `C:\Program Files\osquery\extensions.load` on Windows). Setting `agent_options.extensions` in this fleet would make orbit pass its own autoload file and drop this extension.

Last opened comes from Fleet's own software inventory on every OS, so neither path collects it. `default.yml` sets `report_cap: 10000` because these reports return one row per app or package.

Needs the repository secret `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET` before the first apply.
