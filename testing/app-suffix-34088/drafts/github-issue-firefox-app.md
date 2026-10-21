<!-- Draft for fleetdm/fleet, bug-report template. Not filed. Adam files it.
Labels: bug, :product, customer-ufa, #g-supply-chain, ~software-ingestion
Title: macOS Firefox is ingested as "Firefox.app" on hosts with fleetd tables, which creates duplicate versions -->

**Fleet versions**
  - *Discovered:* 4.90.3
  - *Reproduced:* 4.93.0. Steps 1 to 3 on a lab Mac with fleetd. The same query is in 4.90.3, 4.93.1, and `main`.

**Web browser and operating system**: N/A. This is server-side ingestion for macOS hosts.

<hr/>

### 💥  Actual behavior

On a Mac with the `parse_ini` table, Fleet stores Firefox as `Firefox.app`. On a Mac without it, Fleet stores `Firefox`. The same app ends up with two version rows, split by which hosts have the table. Hosts get `parse_ini` from fleetd, or from osquery with the `fleetd_tables` extension.

The cause is the `macos_firefox` software override in `server/service/osquery_utils/queries.go`. It replaces the Firefox rows from `software_macos` and hard-codes the name:

```sql
CASE WHEN remoting_name.value = 'firefox-esr' THEN 'Firefox ESR.app' ELSE 'Firefox.app' END AS name
```

`software_macos` trims `.app` from every other app, so Firefox is the exception. Fleet's own test expects the `.app` name (`server/datastore/mysql/maintained_apps_test.go`, "A host reports Firefox via osquery").

The hourly `ReconcileMaintainedAppSoftwareNames` job doesn't fix it. Firefox and Firefox ESR share the bundle ID `org.mozilla.firefox`, and the job skips shared bundle IDs unless the title has a Firefox installer.

What this breaks:
- The versions list and `GET /api/v1/fleet/software/versions` show `Firefox.app` and `Firefox` for the same version. Tools that match by name see two products.
- A manual cleanup doesn't last. The next software report from a host with `parse_ini` brings the `Firefox.app` row back.
- #34088 was closed after the title was renamed. The version rows were never fixed.

### 🛠️ Expected behavior

- `macos_firefox` reports `Firefox` and `Firefox ESR`, without `.app`, like `software_macos` does for every other app.
- A migration merges existing `Firefox.app` and `Firefox ESR.app` rows into the matching rows without `.app`, the same way migration `20260810160000_DedupeSoftwareChecksums` merges duplicate giflib rows. Where no matching row exists, the migration renames the row and recomputes its checksum, as migration `20251015103505` did in 4.75.0.
- Software titles named `Firefox.app` are renamed.

### 🧑‍💻  Steps to reproduce

These steps:

- [ ] Have been confirmed to consistently lead to reproduction in multiple Fleet instances.
- [x] Describe the workflow that led to the error, but have not yet been reproduced in multiple Fleet instances.

1. Enroll a Mac with fleetd and Firefox installed, in a fleet that doesn't have the Firefox Fleet-maintained app.
2. Run this live query on it to confirm the table exists:
   ```sql
   SELECT name FROM osquery_registry WHERE registry = 'table' AND name = 'parse_ini';
   ```
3. Run the `macos_firefox` query from `queries.go` as a live query. It returns `Firefox.app`.
4. Enroll a Mac with plain osquery and Firefox, without the `fleetd_tables` extension, in the same fleet.
5. After both hosts report software, run `GET /api/v1/fleet/software/versions?query=firefox`. The same version comes back twice, once as `Firefox.app` and once as `Firefox`.

### 🕯️ More info _(optional)_

- Related, open: #52314. Rows with old checksums also create a second version row, from a different cause.
- Not a duplicate of #50090 (Firefox 153.0 CVE version comparison, fixed for 4.94.0 by #55056) or #50077 (Windows Fleet-maintained app title matching). Neither changes `macos_firefox`, and the `rc-minor-fleet-v4.94.0` branch still hard-codes `Firefox.app`.
- Related, closed: #34088 (`.app` not trimmed), #42445 (Firefox title name with the Fleet-maintained app), and #49682 (Firefox and Firefox ESR in one fleet).
