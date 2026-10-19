# Export software inventory to ServiceNow

ServiceNow IT asset management (ITAM) needs every app on every host, with its publisher, install date, and last use. Fleet's software inventory already has the name, version, install path, and last opened time. This guide adds publisher and install date with custom reports, then syncs everything to ServiceNow every hour with Fleet's REST API. It covers macOS, Windows, and Linux hosts. ChromeOS, iOS, iPadOS, and Android aren't covered, because no publisher or install date source exists there.

> **Note:** A built-in ServiceNow connector is planned ([#38864](https://github.com/fleetdm/fleet/issues/38864)), along with built-in install date ([#54912](https://github.com/fleetdm/fleet/issues/54912)) and publisher ([#54914](https://github.com/fleetdm/fleet/issues/54914)). Use this guide until those ship.

## Prerequisites

- Fleet 4.93.0 or later. It paginates report results in the API and changes how the report cap works.
- An API-only user with the Observer role, and its API token. Observers can read hosts, software, and report results.
- A ServiceNow instance where you can create an Import Set table and a transform map.
- A machine or CI runner with Python 3 that can reach Fleet and ServiceNow every hour.

## Add the reports

Each report uses built-in osquery tables, so hosts need nothing extra installed. Add them to the fleet whose hosts you export. With GitOps, save the list below as `lib/software-itam.reports.yml` and reference it from your fleet file with `- path: ../lib/software-itam.reports.yml` under `reports:`.

```yaml
- name: ITAM macOS app install date
  description: Spotlight date added and bundle creation time for each app.
  query: |
    SELECT a.path, a.bundle_identifier, a.bundle_short_version AS version,
           (SELECT value FROM mdls WHERE path = a.path AND key = 'kMDItemDateAdded') AS date_added,
           CAST(f.btime AS INTEGER) AS bundle_created
    FROM apps a JOIN file f ON f.path = a.path;
  platform: darwin
  interval: 3600
  logging: snapshot
  automations_enabled: false
  observer_can_run: false
- name: ITAM macOS app publisher
  description: Publisher from each app's code signing certificate.
  query: |
    SELECT a.path, s.authority, s.team_identifier
    FROM apps a JOIN signature s ON s.path = a.path
    WHERE s.hash_resources = 0;
  platform: darwin
  interval: 3600
  logging: snapshot
  automations_enabled: false
  observer_can_run: false
- name: ITAM Windows program install date and publisher
  description: InstallDate and Publisher from the Uninstall registry keys.
  query: SELECT name, version, publisher, install_date, identifying_number FROM programs;
  platform: windows
  interval: 3600
  logging: snapshot
  automations_enabled: false
  observer_can_run: false
- name: ITAM Windows uninstall key written
  description: Uninstall key write time, used when InstallDate is empty.
  query: |
    SELECT key, name, CAST(mtime AS INTEGER) AS key_written
    FROM registry
    WHERE key IN ('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                  'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
      AND type = 'subkey';
  platform: windows
  interval: 3600
  logging: snapshot
  automations_enabled: false
  observer_can_run: false
- name: ITAM Linux RPM install date and vendor
  description: Install time and vendor from the RPM database.
  query: SELECT name, version, vendor, CAST(install_time AS INTEGER) AS install_time FROM rpm_packages;
  platform: linux
  interval: 3600
  logging: snapshot
  automations_enabled: false
  observer_can_run: false
- name: ITAM Linux DEB install date and maintainer
  description: Maintainer, and the time dpkg last changed the package.
  query: |
    SELECT d.name, d.version, d.maintainer,
           (SELECT CAST(mtime AS INTEGER) FROM file
             WHERE path IN ('/var/lib/dpkg/info/' || d.name || '.list',
                            '/var/lib/dpkg/info/' || d.name || ':' || d.arch || '.list')) AS list_changed
    FROM deb_packages d;
  platform: linux
  interval: 3600
  logging: snapshot
  automations_enabled: false
  observer_can_run: false
```

Without GitOps, create each report in the Fleet UI under **Reports > Add report** with the same SQL, platform, and an hourly interval.

> **Note:** Every install date here is the best source the OS keeps, not a guaranteed install time. Spotlight's date added and an app bundle's creation time can move when an app updates. Windows InstallDate has day precision and some installers leave it empty. dpkg keeps no install time, so the DEB value is the last time the package changed. The export script labels every date with its source, so ServiceNow shows which one it is.

## Raise the report cap

Fleet stores up to `report_cap` results per report (default 1,000). Fleet raises that to the number of hosts when there are more hosts, which covers reports with one row per host. These reports return one row per app or package, so set the cap for your fleet size. In `default.yml`:

```yaml
org_settings:
  server_settings:
    report_cap: 10000
```

> **Warning:** Rows grow with hosts times apps. 2,000 Macs with 150 apps each is 300,000 rows in one report. Fleet recommends raising the cap one report at a time while you watch database load. For large fleets, set `automations_enabled: true` on the reports and read results from your [log destination](https://fleetdm.com/docs/configuration/fleet-server-configuration#osquery_result_log_plugin) instead.

## Create the ServiceNow import

1. In ServiceNow, create an Import Set table (for example, `u_fleet_sw_install`) with these columns: `installed_on_serial`, `installed_on_name`, `display_name`, `version`, `source`, `publisher`, `publisher_source`, `install_date`, `install_date_source`, `last_used`, `last_used_source`, and `install_location`.
2. Create a transform map from that table to the Software Installation table (`cmdb_sam_sw_install`).
3. Map `installed_on_serial` to the **Installed on** field, coalescing on the computer's serial number so each row lands on the hardware record ServiceNow already has.
4. Map the remaining columns to the matching Software Installation fields. Keep the `*_source` columns, in custom fields or in a note, so auditors can see where each date came from.

> **Note:** Field names on the Software Installation table depend on your ServiceNow version and plugins. Check them on your instance before you build the transform map.

## Run the export every hour

The export script reads Fleet's API, joins the reports to each host's software, and posts the rows to your Import Set table:

1. `GET /api/v1/fleet/hosts` for each host's serial number and name.
2. `GET /api/v1/fleet/hosts/:id/software` for name, version, install path, and last opened time.
3. `GET /api/v1/fleet/reports/:id/report` for the six reports above.
4. `POST /api/now/import/<table>` to ServiceNow.

It matches macOS rows on the app path, and Windows and Linux rows on name and version. Run it without `--post` first to check the output:

```bash
export FLEET_URL=https://fleet.example.com
export FLEET_API_TOKEN=<api-only user token>
python3 sync_fleet_software_to_servicenow.py --fleet-id 3 --out export-out
```

Check `export-out/snow_rows.csv`, then add `--post`:

```bash
export SNOW_USER=<servicenow user>
export SNOW_PASSWORD=<servicenow password>
python3 sync_fleet_software_to_servicenow.py --fleet-id 3 --out export-out \
  --post --snow-instance <instance name> --snow-table u_fleet_sw_install
```

Schedule the second command hourly with cron, a scheduled CI job, or a ServiceNow MID Server. Keep the `--out` folder between runs. The script stores a first seen date there, used when no OS install date exists.

## Verify

1. Pick one Mac and one Windows host. Install an app on each and write down the time.
2. Wait for the next report run (up to an hour), then run the export.
3. In ServiceNow, open the hardware record for each host and find the app under software installations.
4. Confirm the install date matches what you wrote down, and the publisher is the company that ships the app.

## Troubleshoot

**A report stops getting new hosts**

The report reached `report_cap`. Fleet keeps updating hosts already in the report and skips new ones. Raise `report_cap`, or switch the reports to a log destination.

**Windows apps have no install date**

The installer didn't write InstallDate. The script falls back to the Uninstall key write time and labels it `registry_key_written`. A repair or upgrade also rewrites that key.

**Linux packages have no last used date**

Fleet reads last use from file access times. File systems mounted with `noatime` don't record them, and DEB packages need osquery 5.19 or later.

**macOS App Store apps show Apple as the publisher**

The App Store re-signs apps, so the certificate names Apple, not the developer. Use the app's copyright string, or the Team ID in `team_identifier`, to find the developer.

## Further reading

- [Fleet REST API](https://fleetdm.com/docs/rest-api/rest-api)
- [Reports in Fleet](https://fleetdm.com/guides/reports)
- [GitOps YAML files](https://fleetdm.com/docs/configuration/yaml-files)
- [Software inventory](https://fleetdm.com/guides/software-inventory-reference)

<meta name="articleTitle" value="Export software inventory to ServiceNow">
<meta name="authorFullName" value="TODO: author name">
<meta name="authorGitHubUsername" value="TODO: GitHub username">
<meta name="publishedOn" value="TODO: YYYY-MM-DD">
<meta name="category" value="guides">
<meta name="description" value="Sync every app on macOS, Windows, and Linux hosts to ServiceNow hourly, with publisher, install date, and last use.">
