# Results: ".app" software name cleanup


## L-1: Firefox name from a fleetd Mac (2026-10-21): PASS

- Steps: On the lab Fleet (4.93.0), live queries on MPC-Adam: `parse_ini` table present, `tests/macos_firefox.sql`, `tests/main_name.sql`.
- Expected: The override gives `Firefox.app`, the main query gives `Firefox`.
- Actual: As expected. `parse_ini` exists. The override returns `Firefox.app` 157.0.1, the main query returns `Firefox` for the same app. The lab stores `Mozilla Firefox` because this fleet has the Firefox Fleet-maintained app, and the hourly name reconcile renames by that installer link.
- Evidence: `test-evidence/lab/L-1-firefox-name-sent-by-a-fleetd-mac/`
- Finding: Fleet produces `Firefox.app` today on every Mac with `parse_ini`. Without a Firefox installer on the title, the reconcile skips the shared bundle ID and the name stays `Firefox.app`. Fleet's own test expects this (`server/datastore/mysql/maintained_apps_test.go`, "A host reports Firefox via osquery (name "Firefox.app")").


## C1: Self-heal when a host reports (2026-10-21): PASS

- Steps: A host reports `Slack.app` 4.40, then `Slack` 4.40. Run `SyncHostsSoftware`, `CleanupSoftwareTitles`, `SyncHostsSoftwareTitles`.
- Actual: The second report drops the `.app` link and links `Slack`. The orphaned `.app` row is deleted. The title stays `Slack.app`.
- Evidence: `test-evidence/db/<version>/go-test.txt`
- Finding: Rows only stay while their hosts stay offline or keep sending `.app`. Titles always stay.


## C2: Firefox comes back after a manual merge (2026-10-21): PASS

- Steps: A fleetd host reports `Firefox.app`, a plain host reports `Firefox`: two version rows for one app. Merge by hand, then the fleetd host reports again.
- Actual: The `Firefox.app` row is created again and linked after one report.
- Finding: No cleanup of Firefox lasts until `macos_firefox` changes. The plan excludes `org.mozilla.firefox`.


## C3: Diagnose buckets (2026-10-21): PASS

- Steps: Build the fixture (override-era rows on offline hosts, today's rows on online hosts, one orphan, one online host still on `Slack.app`). Add a macOS app row without a bundle ID, with the pre-4.75 checksum (which left the name out), on one host, and let a second host report the same app. Run `sql/1_diagnose.sql`.
- Actual: The second report inserted a twin of the old row: #52314 reproduced through `UpdateHostSoftware`. Buckets: orphaned 1, offline only 2, recurring 1 (Slack.app), recurring Firefox 1. CHECK 4: 1 legacy, 0 unexplained. CHECK 7: one `apps` group of 2 rows.
- Finding: Old-checksum rows are expected on instances upgraded from before 4.75.0. The cleanup skips them, and #52314 tracks them.
- Evidence: `test-evidence/db/<version>/C3-diagnose.txt`


## C4: Cleanup, then ingestion (2026-10-21): PASS

- Steps: Same fixture. `2_plan.sql`, `3_apply_batch.sql` until nothing is pending, and `4_titles.sql`. Then an offline host comes back and a new host reports, through `UpdateHostSoftware`. Then `5_verify.sql` and the vulnerabilities cron functions.
- Actual:
  - Plan: 1 merge (Zoom.app), 1 rename (Notion.app). Slack.app (online host) and Firefox.app (excluded) left alone.
  - Zoom.app deleted. Both offline hosts point at Zoom. The host linked to both kept the newer `last_opened_at`. Its installed path is not doubled.
  - Notion.app keeps its id, is named Notion, and its checksum equals `Software.ComputeRawChecksum` for Notion.
  - After both reports: no new software rows, the new host links to the renamed row, no duplicate versions, no `.app` titles, Notion counts 2 hosts.
- Evidence: `test-evidence/db/<version>/C4-*.txt`


## C5: Fleet-maintained app renames (2026-10-21): PASS
- Steps: An offline host has `Zoom.app` 6.0 and `Notion.app` 3.0. An online host reports `Zoom` 6.0. Add catalog entries for Zoom and Notion, then run Fleet's `ReconcileMaintainedAppSoftwareNames`. Run `1_diagnose.sql`, `2_plan.sql`, and `3_apply_batch.sql`. The offline host reports again, then the job and the vulnerabilities cron functions run.
- Expected: The job turns old `.app` rows into same-name duplicates. Diagnose doesn't block. Pass 2 merges the duplicate. Nothing new is created afterward.
- Actual: The job renamed `Zoom.app` to `Zoom` and `Notion.app` to `Notion`, and kept both checksums. That left two `Zoom` 6.0 rows. CHECK 2 found no `.app` names. CHECK 4 showed 2 `renamed_by_fma` and 0 unexplained. CHECK 9 showed 1 offline-only duplicate. The plan had one `duplicate` merge, and after it one `Zoom` 6.0 row was left. When the host reported again, it kept that row. The old `Notion` row was orphaned and deleted by the cron.
- Evidence: `test-evidence/db/<version>/C5-*.txt`
- Finding: Before this test, the scripts looked only for names ending in `.app`, and CHECK 4 would have told a Premium customer to stop. On Fleet Premium, most old `.app` rows of common apps are now same-name duplicates.

## C6: Never merge into an orphan (2026-10-21): PASS
- Steps: A `Zoom` 5.0 group after the Fleet-maintained app job ran: an orphan, an old `Zoom.app` row on an offline host, and the `zoom.us` row online hosts use. Also `Slack.app` on the offline host, whose only twin `Slack` is an orphan. Plan and apply.
- Actual: Pass 2 picked the row online hosts use as survivor, not the orphan. `Slack.app` was skipped as `skip_orphan_twin`. No host link or path points at a missing row.
- Finding (from the SQL review): before this fix, a merge could target an orphan the vulnerabilities cron was about to delete.

## C7: Bundle ID fallback (2026-10-21): PASS
- Steps: `Visual Studio Code.app` 1.85 on an offline host, `Code` 1.85 online, same bundle ID. `Postman Helper.app` 11.0 offline, and `Postman Helper (GPU)` and `Postman Helper (Renderer)` online with the same bundle ID. Plan and apply. Then the offline host reports again.
- Actual: VS Code merged into `Code` with `pair_by` bundle. The helper has two candidates, so it was renamed to `Postman Helper` instead of merged. Reporting again created no rows.
- Finding (from the SQL review): before this fix, the VS Code row would have been renamed to a name no host sends, leaving two rows for one version.

## C8: No chains (2026-10-21): PASS
- Steps: `Foo.app.app` and `Foo.app` (with a bundle ID) and `Bar.app.app` and `Bar.app` (without) on offline hosts. `Foo` and `Bar` online. Plan, apply, and verify.
- Actual: Both Foo rows merged into `Foo`, the chain through the bundle ID fallback. `Bar.app` merged into `Bar`. `Bar.app.app` was skipped as `skip_stale_twin`. No host link or path points at a missing row.

## CL-1: Scripts through the mysql client (2026-10-21): PASS
- Steps: `tests/run-client-smoke.sh` loads Fleet's `schema.sql` into the `mysql_test` container (MySQL 8.0.44, `enforce_gtid_consistency` on, row-based binlog), adds `tests/fixture-client.sql`, and runs every script with `mysql --default-character-set=utf8mb4`, which connects with `utf8mb4_0900_ai_ci`. It also runs `2_plan.sql` without its `SET NAMES` line.
- Actual: Without `SET NAMES`, the plan fails with `ERROR 1267 ... Illegal mix of collations`. With it, all five scripts exit 0. The end state: `Zoom.app` merged into `Zoom` with its installed path moved, `Notion.app` renamed to `Notion`, and the title renamed to `Zoom`.
- Evidence: `test-evidence/client/<version>/`
- Finding (from the SQL review): the Go test connects with Fleet's own settings, which set the collation, so it couldn't catch this.

## Versions

C1 to C8 and CL-1 pass on `fleet-v4.90.3` (customer production), `fleet-v4.93.1` (customer's next upgrade), and `main` at e1cf388cca. One folder per version under `test-evidence/db/`.


## N-1: Negative control (2026-10-21): PASS

- Steps: A copy of `sql/` with `s.version, s.source` swapped in the checksum.
- Actual: C3 to C8 fail. CHECK 4 reports mismatches, and pass 1 selects nothing, because it only takes rows whose stored checksum matches the formula. A wrong formula fails safe. A first attempt that swapped `extension_for` and `extension_id` still passed, because both are empty for macOS apps.
- Evidence: `test-evidence/db/negative-control.txt`
