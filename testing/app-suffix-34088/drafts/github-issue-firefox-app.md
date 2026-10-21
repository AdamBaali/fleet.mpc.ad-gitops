<!-- Draft for fleetdm/fleet, bug-report template. Not filed. Adam files it.
Labels: bug, :product, customer-ufa, #g-supply-chain, ~software-ingestion
Title: macOS Firefox ingests as "Firefox.app" on hosts with fleetd tables, creating duplicate versions -->

**Fleet versions**
  - *Discovered:* 4.90.3
  - *Reproduced:* 4.93.0 (lab), 4.93.1 and `main` at e1cf388cca (database tests)

**Web browser and operating system**: N/A. Server ingestion, macOS hosts.

<hr/>

### 💥  Actual behavior

On a Mac with the `parse_ini` table (fleetd, or osquery with the fleetd tables extension), Fleet stores Firefox as `Firefox.app`. On a Mac without it, Fleet stores `Firefox`. One app, two version rows, split by whether the host has fleetd tables.

The cause is the `macos_firefox` software override in `server/service/osquery_utils/queries.go`. It replaces the Firefox rows from `software_macos` and hard-codes the name:

```sql
CASE WHEN remoting_name.value = 'firefox-esr' THEN 'Firefox ESR.app' ELSE 'Firefox.app' END AS name
```

`software_macos` trims `.app` from every other app, so Firefox is the exception. Fleet's own test expects it: `server/datastore/mysql/maintained_apps_test.go`, "A host reports Firefox via osquery (name "Firefox.app")".

The hourly `ReconcileMaintainedAppSoftwareNames` job does not fix it, because Firefox and Firefox ESR share `org.mozilla.firefox`, and the job skips shared bundle IDs unless the title has a Firefox installer.

Effects:
- The versions list and `/api/v1/fleet/software/versions` show `Firefox.app` and `Firefox` for the same version. Pipelines that match by name see two products.
- A cleanup cannot last. Merging the `Firefox.app` rows by hand brings them back on the next report.
- #34088 was closed after a title rename. The version rows were never fixed.

### 🛠️ Expected behavior

- `macos_firefox` reports `Firefox` and `Firefox ESR`, the same names `software_macos` gives (trimmed, no `.app`).
- A migration merges existing `Firefox.app` and `Firefox ESR.app` rows into the trimmed rows: move `host_software` and `host_software_installed_paths` links, keep the newer `last_opened_at`, delete the old rows and their `software_cve` and `software_host_counts` rows. Where no trimmed row exists, rename the row and recompute its checksum together, as migration `20251015103505` did in 4.75.0.
- Titles named `Firefox.app` are renamed.

A tested SQL version of the merge and rename, with a Go test against Fleet's ingestion, is in [AdamBaali/fleet.mpc.ad-gitops, `testing/app-suffix-34088`](https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/app-suffix-34088). It may help with the migration.

### 🧑‍💻  Steps to reproduce

These steps:

- [x] Have been confirmed to consistently lead to reproduction in multiple Fleet instances.
- [ ] Describe the workflow that led to the error, but have not yet been reproduced in multiple Fleet instances.

1. Enroll a Mac with fleetd and Firefox installed.
2. Confirm the table exists with a live query:
   ```sql
   SELECT name FROM osquery_registry WHERE registry = 'table' AND name = 'parse_ini';
   ```
   Then run the `macos_firefox` query from `queries.go` as a live query. It returns `Firefox.app`.
3. Enroll a Mac with plain osquery (no fleetd tables) and Firefox.
4. Open Software, search Firefox, show versions. Both `Firefox.app` and `Firefox` appear for the same version, unless the fleet has the Firefox Fleet-maintained app.

### 🕯️ More info _(optional)_

- Related, open: #52314 (rows from before 4.76.0 duplicate). Same symptom, two version rows for one app, different cause.
- Related, closed: #34088 (`.app` not trimmed), #42445 (Firefox title name with the Fleet-maintained app), #49682 (Firefox and Firefox ESR in one fleet).
- Customers on osquery with the fleetd tables extension get the split on every Mac that has the extension, so the count is large.
