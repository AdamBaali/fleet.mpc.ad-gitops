# Notes: ".app" software name cleanup

## The October handoff, checked claim by claim
Sources: Fleet `main` at e1cf388cca and tags `fleet-v4.90.3`, `fleet-v4.93.1`, the GitHub API, and the tests in this folder.

| Claim in the handoff | Verdict | What is true |
|---|---|---|
| Customer label is `customer-ufa` | Confirmed | The label exists and is on #34088, #34159, #34157 |
| #34620 is part of the customer's issue family | Wrong | #34620 has no customer label. Milestone 4.82.0, closed 2026-03-12 |
| #39563 is a closed issue fixed in 4.82.0 | Wrong type | #39563 is a pull request, merged 2026-02-10, that resolves #34620. It shipped in 4.82.0 |
| 4.82.0 is the floor for the ingestion fix | Misleading | Lowercase `.app` was trimmed long before. 4.82.0 fixed over-trimming. No version stops Firefox from arriving as `Firefox.app` (L-1) |
| `software_macos` reads the core `apps` table, so osquery versus fleetd does not matter | Incomplete | True for `software_macos`. But `macos_firefox` replaces Firefox rows on any host with `parse_ini` (fleetd tables), and it sends `.app`. For Firefox it matters |
| `mergeSoftwareRow` (~3514), `reconcileSoftwareGroup`, `findGroupsStmt`, `execReconcileBatches`, `reconcileGroupsPerRun`, `reconcileRepointBatch` are Fleet's merge routine | Not found | None of these names exist in Fleet `main` or the tags above. The SQL was not built from real Fleet code |
| 4.90.0 shipped duplicate-software checksum reconciliation | Wrong | 4.90.0 shipped a one-shot migration that renames titles only (login helper names, `20260723181405_FixEmbeddedBundleTitleNames`). The duplicate merge was in 4.91.0 and covers giflib Homebrew rows only |
| `PATCH /api/v1/fleet/software/titles/:id/name` changes titles only | Confirmed | `UpdateSoftwareTitleName`, and only for titles with a bundle ID |
| Renaming `software` in SQL is unsafe | Half true | Renaming the name alone is unsafe: new hosts miss the row by checksum and insert a duplicate. Renaming name and checksum together is what Fleet's 4.75.0 migration did (`20251015103505_AddNameToSoftwareCheckumCalculation`). Fleet also renames `software.name` in place every hour for Fleet-maintained apps (`ReconcileMaintainedAppSoftwareNames`). C5 shows name plus checksum is safe |
| Checksum formula: MD5 of version, source, bundle ID, release, arch, vendor, extension_for, extension_id, name, then application ID and upgrade code if set | Confirmed | `Software.ComputeRawChecksum`, `server/fleet/software.go`. C4 and C5 check it against Go |
| A `.app` row still linked to hosts never leaves | Wrong | A host's report replaces its whole software list, keyed by name. Reporting `Slack` drops the `Slack.app` link in the same report (C1). Links stay only on offline hosts and hosts that still send `.app` |
| `software_cve` and `software_host_counts` have no foreign key, `software_cpe` cascades | Confirmed | `software_metadata` also cascades, which the handoff missed |
| `fleetctl trigger --name cleanups_then_aggregation` rebuilds counts and removes titles | Wrong | `SyncHostsSoftware`, `CleanupSoftwareTitles` and `SyncHostsSoftwareTitles` run in the `vulnerabilities` schedule (`cmd/fleet/vuln_process.go`) |
| Preflight CHECK 2 detects recurrence with `host_updates.software_updated_at` | Weak | That time changes only when a host's software changes. A host that keeps sending the same `.app` name never shows. `1_diagnose.sql` uses `host_seen_times` |
| `2_execute.sql` is batched, idempotent and mirrors Fleet | Wrong | It does not run. MySQL error 1064 at STEP 2, after STEP 1 has written, no transaction (C3) |
| `fleetdm/confidential` has nothing on this | Confirmed | The repo has `customer-ufa` issues, none about `.app` names |
| The customer went silent | Out of date | The customer asked again and named the Firefox cause in October 2026. See `private/` |
| Customer stuck on 4.89 | Out of date | Production is on 4.90.3 and plans 4.93 |

## How Fleet ingests macOS software, as it matters here
- `software_macos` builds the name from `display_name`, then `bundle_name`, then `bundle_executable` (unless `run.sh`), then the `.app` file name without `.app`.
- `macos_firefox` runs where `parse_ini` exists, removes the Firefox rows from `software_macos`, and adds its own with `Firefox.app` or `Firefox ESR.app` (`server/service/osquery.go`, `removeOverrides`).
- `UpdateHostSoftware` compares the stored list with the reported list by `ToUniqueStr` (name, version, source, bundle ID, and more). Anything missing is unlinked. Anything new is found by checksum or inserted.
- `SyncHostsSoftware` rebuilds host counts and deletes software with no hosts. It runs in the vulnerabilities schedule.
- A title is created once per bundle ID and never renamed by ingestion. Firefox and Firefox ESR share one title because they share `org.mozilla.firefox`.
- `ReconcileMaintainedAppSoftwareNames` (hourly) renames titles and software to the Fleet-maintained app name, but skips bundle IDs shared by two apps, like Firefox, unless the title has that app's installer.

## Why each script choice was made
- **Merge or rename, decided by checksum.** The twin is found the way ingestion finds it, so the result matches what ingestion expects.
- **Only rows whose stored checksum matches the formula.** This proves the formula on the customer's own data, row by row. A wrong formula selects nothing (N-1).
- **Offline-only rows.** Rows on online hosts are still being sent and would come back. Orphans are deleted by Fleet.
- **One transaction per batch, re-checked before each batch.** Fleet keeps running. A host can report between batches.
- **Titles separate.** They have no checksum and the API already does the same per title.
- **Display names reported, not changed.** An admin chose them.
- **CPE and CVE rows kept on renamed rows.** Same app and version, and macOS CPEs come from the bundle ID. The next vulnerability run refreshes them.

## Not tested, and differences from production
- Customer data volume. CHECK 2 and the plan join `host_software` by `software_id`, which has an index, but no plan was measured at their size.
- The customer's MySQL flavor and version. Tests used MySQL 8.0.44.
- Live crons running during a batch.
- Firefox ESR. The override names it `Firefox ESR.app`. The exclusion covers it through the shared bundle ID.
- Whether the customer re-enabled a detail query override after September 2025. No sign of it. CHECK 1 answers it.
