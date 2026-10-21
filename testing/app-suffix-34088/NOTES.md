# Notes: ".app" software name cleanup


## How Fleet ingests macOS software, as it matters here

- `software_macos` builds the name from `display_name`, then `bundle_name`, then `bundle_executable` (unless `run.sh`), then the `.app` file name without `.app`.
- `macos_firefox` runs where `parse_ini` exists, removes the Firefox rows from `software_macos`, and adds its own with `Firefox.app` or `Firefox ESR.app` (`server/service/osquery.go`, `removeOverrides`).
- `UpdateHostSoftware` compares the stored list with the reported list by `ToUniqueStr` (name, version, source, bundle ID, and more). Anything missing is unlinked. Anything new is found by checksum or inserted.
- `SyncHostsSoftware` rebuilds host counts and deletes software with no hosts. It runs in the vulnerabilities schedule.
- A title is created once per bundle ID, and software ingestion never renames it. Firefox and Firefox ESR share one title because they share `org.mozilla.firefox`.
- `ReconcileMaintainedAppSoftwareNames` (hourly, Fleet Premium) renames titles and `software` rows to the name in Fleet's catalog of maintained apps. It changes `software.name` only, by primary key, and keeps the checksum of the name the host reported. It skips bundle IDs shared by two apps, like Firefox, unless the title has that app's installer. Old `.app` rows of catalog apps become same-name duplicates of today's rows (C5).


## Facts the scripts rely on

Checked in Fleet `main` at e1cf388cca and tags `fleet-v4.90.3` and `fleet-v4.93.1`.
- Checksum. `Software.ComputeRawChecksum` (`server/fleet/software.go`) is MD5 of version, source, bundle ID, release, arch, vendor, extension_for, extension_id, and name, joined by `\x00`, then application ID and upgrade code when set. `software.checksum` is a unique key, and ingestion looks rows up by it.
- Renaming a software row. The name and the checksum must change together, or a new host misses the row and inserts a duplicate. Fleet's 4.75.0 migration `20251015103505` recomputed macOS app checksums in SQL the same way. Fleet also renames `software.name` in place every hour for Fleet-maintained apps.
- Merging a software row. `host_software` has the primary key (host_id, software_id), so a host linked to both rows keeps one link. `host_software_installed_paths` has no unique key. `software_cve`, `software_host_counts`, and `kernel_host_counts` have no foreign key to `software`. `software_cpe` cascades on delete, and so does `software_metadata`, which exists on `main` but not in 4.90.3 or 4.93.1. At 4.90.3 and 4.93.1, nothing else references `software.id`.
- Titles. `PATCH /api/v1/fleet/software/titles/:id/name` (contributor API) renames a title with a bundle ID and nothing else. `software_titles.unique_identifier` falls back to the name when there is no bundle ID, application ID, or upgrade code.
- Rows the Fleet-maintained app job renamed. Their checksum belongs to the name hosts report, not the stored name. Recomputing it would make hosts miss the row and insert a duplicate, so the scripts never recompute it. CHECK 4 counts these as `renamed_by_fma`.
- Counts and orphans. `SyncHostsSoftware`, `CleanupSoftwareTitles`, and `SyncHostsSoftwareTitles` run in the `vulnerabilities` schedule (`cmd/fleet/vuln_process.go`).


## Why each script choice was made

- Merge or rename, decided by checksum. The script finds the twin the way ingestion does, so the result matches what ingestion expects.
- A bundle ID fallback for pass 1. Fleet names apps from the bundle first, so the row hosts report today can have another name than the trimmed file name ("Visual Studio Code.app" next to "Code"). When there's no checksum twin, the script merges into the one row with the same bundle ID, version, and identity that hosts still use. With more than one candidate (apps that share a bundle ID, like helper apps), it doesn't (C7).
- Only rows whose stored checksum matches the formula, in pass 1. This proves the formula against the customer's own data, row by row. A wrong formula selects nothing (N-1).
- Pass 2 never recomputes checksums. Rows the Fleet-maintained app job renamed keep the checksum of the name hosts report.
- Offline-only rows. Online hosts still send these names, so the rows would come back. Fleet deletes orphans itself.
- Never merge into an orphan. The vulnerabilities cron picks orphans on the reader and deletes them without checking again, so links moved onto one could end up pointing at a deleted row. The survivor must have host links (C6).
- No chains. A row already in the plan is never another row's survivor (C8).
- One transaction per batch, re-checked before each batch. Fleet keeps running, and a host can report between batches. The final state of each row comes from what happened (merged, renamed, or failed), not from what was planned.
- READ COMMITTED. Under the default REPEATABLE READ, `INSERT ... SELECT` locks the rows it reads, which blocked Fleet's software inserts in the review's lock test. READ COMMITTED doesn't lock them.
- `STRAIGHT_JOIN` from the plan's stale rows, and installed paths reached through `host_software`, as Fleet's own merge does. Otherwise MySQL can scan and lock the links or paths of online hosts.
- `SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci`. Fleet's tables use that collation. A MySQL 8 client defaults to `utf8mb4_0900_ai_ci`, and the plan then fails with error 1267 (client smoke test).
- Titles separate, and only titles with a bundle ID, like the contributor API. Ingestion finds titles without a bundle ID by name, so renaming those could create a second title.
- Display names reported, not changed. An admin chose them.
- CPE and CVE rows kept on renamed rows. Fleet recomputes CPEs for all software on each vulnerability run (`TranslateSoftwareToCPE` with `AllSoftwareIterator`, `server/vulnerabilities/nvd/cpe.go`).


## How to run the scripts

- With the `mysql` command-line client, for example `mysql ... fleet < 3_apply_batch.sql`. It stops at the first error and rolls the batch back. Never use `--force`, and don't use a GUI that keeps going after an error.
- On the primary, after a snapshot.
- READ COMMITTED needs `binlog_format` ROW or MIXED, or the binary log off. Check with `SELECT @@binlog_format, @@log_bin`.


## Not tested, and differences from production

- Customer data volume. The review ran the scripts on 202,000 software rows and 280,000 host links with `EXPLAIN` and two-session lock tests, but not at the customer's size.
- The customer's MySQL flavor and version. Tests used MySQL 8.0.44 with `enforce_gtid_consistency` on and row-based binlog.
- A batch running while Fleet's crons or ingestion run at the same moment. The tests run ingestion and the crons between batches, not during one.
- Firefox ESR. The override names it `Firefox ESR.app`. The exclusion covers it through the shared bundle ID.
- Whether the customer re-enabled a detail query override after September 2025. No sign of it. CHECK 1 answers it.
- Restoring from the `zz_` backup tables. The rollback is the database snapshot. The backup tables are for looking up what changed.
