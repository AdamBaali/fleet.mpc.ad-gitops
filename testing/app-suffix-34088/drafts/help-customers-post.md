<!-- Post for #help-customers, from Adam. Not posted. Tag the on-call engineer for #g-supply-chain. -->
Review request: SQL cleanup for `.app` software names (`customer-ufa`)

@<on-call engineer> can you review these scripts before we send them to the customer? We told them engineering would review the scripts this week.

The problem: macOS software versions named `Firefox.app` next to `Firefox`, which breaks name matching in their vulnerability pipeline. They're self-hosted on 4.90.3 and upgrading to 4.93. Their Macs run plain osquery with the `fleetd_tables` extension.

Timing: they'll run the scripts after the 4.93 upgrade. The upgrade runs migration `20260810160000` (giflib merge) first.

Causes we found:
- Firefox: `macos_firefox` in `queries.go` hard-codes `Firefox.app` and `Firefox ESR.app` on any host with `parse_ini`. We saw it on a lab Mac on 4.93.0. A cleanup comes back on the next software report, so the scripts skip Firefox. I'm filing a bug for a product fix.
- Other apps: left over from a `software_macos` override they removed in September 2025 (#33140). These rows clear when hosts report, so only rows on long-offline hosts stay.
- Titles: ingestion never renames an existing title.

What the scripts do:
1. `1_diagnose.sql` (read-only) sorts the `.app` rows into still produced, offline only, and orphaned. It checks for overrides, checks the checksum formula against their data, lists titles, and counts #52314 duplicates.
2. `4_titles.sql` trims `.app` from title names, like the contributor API title rename, in bulk.
3. `2_plan.sql`, then `3_apply_batch.sql` (repeat until done), then `5_verify.sql`. For `.app` rows on offline hosts only, these merge each row into its twin without `.app`, found by checksum. If there's no twin, they rename the row and recompute its checksum. The merge follows `mergeDuplicateSoftware` in migration `20260810160000`. Each batch is one transaction, and Fleet keeps running.

What we've checked: a Go test runs the scripts in Fleet's test database with `UpdateHostSoftware` and the vulnerabilities cron functions, on 4.90.3, 4.93.1, and `main`. After the cleanup, hosts that report again create no new rows and no duplicates. The scripts haven't run on a real instance yet.

Please check:
- Do the merge and rename steps match how ingestion links hosts, especially renaming the name and checksum in place?
- Do we miss any table that references `software.id`? We cover `host_software`, `host_software_installed_paths`, `software_cve`, and `software_host_counts`, plus the cascades on `software_cpe` and `software_metadata`.
- Is the lock time OK when `3_apply_batch.sql` runs on a large live instance, in batches of 100 rows?

Also: #52314 (rows with old checksums create a second version row) may explain their TeamViewer duplicates, and it doesn't have the `customer-ufa` label yet. Is anyone picking it up?

Scripts: https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/app-suffix-34088/sql
