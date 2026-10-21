# Notes: ".app" software name cleanup


## How Fleet ingests macOS software, as it matters here

- `software_macos` builds the name from `display_name`, then `bundle_name`, then `bundle_executable` (unless `run.sh`), then the `.app` file name without `.app`.
- `macos_firefox` runs where `parse_ini` exists, removes the Firefox rows from `software_macos`, and adds its own with `Firefox.app` or `Firefox ESR.app` (`server/service/osquery.go`, `removeOverrides`).
- `UpdateHostSoftware` compares the stored list with the reported list by `ToUniqueStr` (name, version, source, bundle ID, and more). Anything missing is unlinked. Anything new is found by checksum or inserted.
- `SyncHostsSoftware` rebuilds host counts and deletes software with no hosts. It runs in the vulnerabilities schedule.
- A title is created once per bundle ID and never renamed by ingestion. Firefox and Firefox ESR share one title because they share `org.mozilla.firefox`.
- `ReconcileMaintainedAppSoftwareNames` (hourly) renames titles and software to the Fleet-maintained app name, but skips bundle IDs shared by two apps, like Firefox, unless the title has that app's installer.


## Facts the scripts rely on

Checked in Fleet `main` at e1cf388cca and tags `fleet-v4.90.3` and `fleet-v4.93.1`.
- Checksum. `Software.ComputeRawChecksum` (`server/fleet/software.go`) is MD5 of version, source, bundle ID, release, arch, vendor, extension_for, extension_id, and name, joined by `\x00`, then application ID and upgrade code when set. `software.checksum` is a unique key, and ingestion looks rows up by it.
- Renaming a software row. The name and the checksum must change together, or a new host misses the row and inserts a duplicate. Fleet's 4.75.0 migration `20251015103505` recomputed macOS app checksums in SQL the same way. Fleet also renames `software.name` in place every hour for Fleet-maintained apps.
- Merging a software row. `host_software` has the primary key (host_id, software_id), so a host linked to both rows keeps one link. `host_software_installed_paths` has no unique key. `software_cve` and `software_host_counts` have no foreign key to `software`. `software_cpe` and `software_metadata` cascade on delete.
- Titles. `PATCH /api/v1/fleet/software/titles/:id/name` (contributor API) renames a title with a bundle ID and nothing else. `software_titles.unique_identifier` falls back to the name when there is no bundle ID, application ID, or upgrade code.
- Counts and orphans. `SyncHostsSoftware`, `CleanupSoftwareTitles`, and `SyncHostsSoftwareTitles` run in the `vulnerabilities` schedule (`cmd/fleet/vuln_process.go`).


## Why each script choice was made

- Merge or rename, decided by checksum. The script finds the twin the way ingestion does, so the result matches what ingestion expects.
- Only rows whose stored checksum matches the formula. This proves the formula on the customer's own data, row by row. A wrong formula selects nothing (N-1).
- Offline-only rows. Online hosts still send these names, so the rows would come back. Fleet deletes orphans itself.
- One transaction per batch, re-checked before each batch. Fleet keeps running. A host can report between batches.
- Titles separate. They have no checksum and the API already does the same per title.
- Display names reported, not changed. An admin chose them.
- CPE and CVE rows kept on renamed rows. Same app and version, and macOS CPEs come from the bundle ID. The next vulnerability run refreshes them.


## Not tested, and differences from production

- Customer data volume. CHECK 2 and the plan join `host_software` by `software_id`, which has an index, but no plan was measured at their size.
- The customer's MySQL flavor and version. Tests used MySQL 8.0.44.
- Live crons running during a batch.
- Firefox ESR. The override names it `Firefox ESR.app`. The exclusion covers it through the shared bundle ID.
- Whether the customer re-enabled a detail query override after September 2025. No sign of it. CHECK 1 answers it.
