# Test plan: ".app" software name cleanup

Issue: fleetdm/fleet#34088 (closed), `customer-ufa` · Owner: Adam Baali · Started: 2026-10-21


## Scope

Why `.app` names exist, whether they come back, and whether the cleanup SQL is safe against Fleet's real ingestion. Not covered: the customer's data volume and query plans at their scale.


## Environment

| Item | Value |
|---|---|
| Lab Fleet | `https://fleet.mpc.ad`, 4.93.0 |
| Lab host | MPC-Adam, macOS 15.7.7, fleetd (orbit 1.61.0, osquery 5.24.0), Firefox 157.0.1 |
| Database tests | Fleet's `mysql_test` container (MySQL 8.0.44, `enforce_gtid_consistency` on, row-based binlog), Fleet schema and Go code at `fleet-v4.90.3`, `fleet-v4.93.1`, and `main` (e1cf388cca) |
| Customer | Self-hosted, production on 4.90.3, upgrading to 4.93. Plain osquery with a fleetd tables extension on most Macs |
| Lab differences from production | One host, not tens of thousands. MySQL 8.0.44, not the customer's managed MySQL. No detail query override in the lab |


## Tests

| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| L-1 | Firefox name from a fleetd Mac | Live query `macos_firefox` and the main name expression on the lab Mac | Override gives `Firefox.app`, main query gives `Firefox` | Both outputs show it |
| C1 | Self-heal | Host reports `Slack.app`, then `Slack`. Run the vulnerabilities cron functions | Link moves, `.app` row deleted, title keeps `.app` | Go assertions |
| C2 | Firefox comes back | Merge `Firefox.app` by hand, then a fleetd host reports again | `.app` row is recreated | Go assertions |
| C3 | Diagnose | Build the customer-like fixture plus a macOS app row with the pre-4.75 checksum (no name), let a second host report that app, run `sql/1_diagnose.sql` | The old row duplicates (#52314). Buckets: 1 orphaned, 2 offline only, 1 recurring, 1 recurring Firefox. CHECK 4: 1 legacy, 0 unexplained. CHECK 7: 1 apps group of 2 rows | Go assertions |
| C4 | Cleanup, then ingestion | Run `2_plan`, `3_apply_batch` until done, and `4_titles`. Then an offline host and a new host report | Zoom merges, Notion renames with Go's checksum, Slack and Firefox untouched, paths not doubled, newer last opened kept, no new software rows, no duplicate versions, no `.app` titles | Go assertions |
| C5 | Fleet-maintained app renames | Old `.app` rows on an offline host, catalog entries for Zoom and Notion, then Fleet's `ReconcileMaintainedAppSoftwareNames`. Diagnose, plan, apply, then the host reports and the job runs again | The job turns `Zoom.app` into a second `Zoom` row. CHECK 4 shows 0 unexplained. Pass 2 merges the duplicate. No new rows afterward | Go assertions |
| C6 | Never merge into an orphan | A duplicate group with an orphan, an old row on an offline host, and the row online hosts use. A `.app` row whose only twin is an orphan | Pass 2 merges into the row online hosts use. The `.app` row is skipped as `skip_orphan_twin`. No link points at a missing row | Go assertions |
| C7 | Bundle ID fallback | `Visual Studio Code.app` offline, `Code` online, same bundle ID and version. `Postman Helper.app` offline, two helpers online with the same bundle ID | VS Code merges into `Code` (`pair_by` bundle). The helper is renamed, not merged. Reporting again creates nothing | Go assertions |
| C8 | No chains | `Foo.app.app` and `Foo.app` with a bundle ID, `Bar.app.app` and `Bar.app` without | Both Foo rows merge into `Foo`. `Bar.app` merges, `Bar.app.app` is skipped as `skip_stale_twin`. No link points at a missing row | Go assertions |
| CL-1 | Scripts through the `mysql` client | Load Fleet's `schema.sql`, add a small fixture, run every script with `mysql --default-character-set=utf8mb4`. Also run `2_plan.sql` without its `SET NAMES` line | Without `SET NAMES`: error 1267. With it: every script exits 0 and the end state is right | Exit codes and end state |
| N-1 | Negative control | C3 and C4 with a wrong checksum field order | C3 to C8 fail, and pass 1 selects nothing | They fail |


## Out of scope / not tested

- The customer's data, row counts, and query times. `1_diagnose.sql` is the first step there.
- A Fleet server process running crons during `3_apply_batch.sql`. The test calls ingestion between batches, not during one.
- Restoring from the `zz_` backup tables. The rollback is a database snapshot.
