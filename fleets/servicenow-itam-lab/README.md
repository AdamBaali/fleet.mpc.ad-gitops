# ServiceNow ITAM Lab

Purpose: test which software fields Fleet can export to ServiceNow ITAM on each OS (fleetdm/fleet#38864). Tests and results: `testing/servicenow-itam-38864/`.

Hosts: one Mac, one Windows 11 VM, one Fedora host, one Ubuntu host.

| Report file | Fills |
| --- | --- |
| `lib/macos/reports/software-itam.reports.yml` | Install date proxies, publisher from code signing, pkg receipts |
| `lib/windows/reports/software-itam.reports.yml` | Install date and publisher from Programs, last run from Prefetch and UserAssist |
| `lib/linux/reports/software-itam.reports.yml` | RPM install time and vendor, DEB last changed and maintainer |

Needs the repository secret `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET` before the first apply.
