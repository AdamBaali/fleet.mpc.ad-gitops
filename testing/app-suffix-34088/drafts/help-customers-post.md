<!-- Post for #help-customers, from Adam. Not posted. Tag the on-call engineer for #g-supply-chain. Links work once the folder is on main. -->
*Review request: SQL cleanup for `.app` software names (`customer-ufa`)*
@<on-call engineer> can you review these scripts before we send them to the customer? They were promised scripts reviewed by engineering this week.

*Problem:* macOS versions named `Firefox.app` next to `Firefox`, which breaks name matching in their vulnerability pipeline. Self-hosted, production on 4.90.3, upgrading to 4.93. Plain osquery with the fleetd tables extension.

*Causes we found*
• Firefox: `macos_firefox` in `queries.go` hard-codes `Firefox.app` and `Firefox ESR.app` on any host with `parse_ini`. Reproduced on 4.93.0. A cleanup comes back within the hour, so the scripts skip Firefox. Bug draft for a product fix is linked below.
• Other apps: left from a `software_macos` override removed in Sep 2025 (#33140). These clear when hosts report. Only rows on long-offline hosts stay.
• Titles: never renamed by ingestion.

*What the scripts do* (`1_diagnose` is read only, the rest write)
1. `1_diagnose.sql`: buckets `.app` rows (still produced, offline only, orphaned), checks overrides, checks the checksum formula on their data, sizes #52314.
2. `4_titles.sql`: trims `.app` from titles. Same as the contributor title rename endpoint, in bulk.
3. `2_plan.sql` → `3_apply_batch.sql` (repeat) → `5_verify.sql`: for offline-only `.app` rows, merges into the correctly named twin found by checksum, or renames name and checksum together when there is no twin. Same steps as `mergeDuplicateSoftware` in migration `20260810160000`. One transaction per batch, Fleet keeps running.

*Tested:* Go test inside Fleet's test DB with `UpdateHostSoftware` and the vulnerabilities cron functions, on 4.90.3, 4.93.1 and main. After cleanup, hosts reporting again create no new rows and no duplicates. The renamed row's checksum equals `ComputeRawChecksum`.

*Please check*
• Merge and rename steps against how ingestion links hosts, especially renaming name and checksum in place.
• Anything we miss that references `software.id`. We cover `host_software`, `host_software_installed_paths`, `software_cve`, `software_host_counts`, and the cascades on `software_cpe` and `software_metadata`.
• Running `3_apply_batch.sql` on a large instance while Fleet is live (lock time, batch size 100).

*Also:* #52314 (rows from before 4.76.0 duplicate) fits their TeamViewer duplicates and has no `customer-ufa` label yet. Is anyone picking it up?

Scripts and evidence: https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/app-suffix-34088
Bug draft: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/app-suffix-34088/drafts/github-issue-firefox-app.md
