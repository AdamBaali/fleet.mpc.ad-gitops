# macOS software names ending in ".app" (fleetdm/fleet#34088, `customer-ufa`)

A customer sees macOS software versions named `Firefox.app` next to `Firefox`, and asked for a safe way to clean them up. This folder holds the verified diagnosis, tested SQL, and the evidence. Same method as `../_framework`.

No customer or person names in this folder. Refer to the customer by the `customer-ufa` label and to the request by public issue numbers. Internal links (Slack, Pylon, call notes) live in `private/`, which git ignores.

## What we found
1. **Firefox is still produced today, by Fleet.** The `macos_firefox` detail query hard-codes the names `Firefox.app` and `Firefox ESR.app` (`server/service/osquery_utils/queries.go`, Fleet 4.93.1 and `main`). It runs on any Mac with the `parse_ini` table: fleetd, or osquery with the fleetd tables extension. Reproduced on the lab Fleet (L-1). A cleanup of Firefox rows comes back within an hour (C2). This needs a Fleet fix: [drafts/github-issue-firefox-app.md](drafts/github-issue-firefox-app.md).
2. **Other `.app` rows are left from 2025** and come from a custom `software_macos` detail query override that the customer removed in September 2025 (fleetdm/fleet#33140). They heal on their own: a host that reports the trimmed name drops the `.app` link in the same report, and the vulnerabilities cron deletes the orphaned row (C1). Only rows on hosts that stay offline remain.
3. **Titles never heal.** Ingestion never renames an existing title, so a `.app` title stays until someone renames it (C1).
4. **The handoff's SQL does not run.** `2_execute.sql` stops with MySQL error 1064 at its second step, after its first step has written outside a transaction (C3). The handoff also cites Fleet functions that do not exist. Details in [NOTES.md](NOTES.md).

## The plan for the customer
1. Run `sql/1_diagnose.sql` (read only). It splits `.app` rows into recurring, offline only and orphaned, and checks the checksum formula on their data.
2. Rename titles: `sql/4_titles.sql`, or the contributor API per title.
3. Optional: merge or rename the offline-only rows with `sql/2_plan.sql` and `sql/3_apply_batch.sql`, then check with `sql/5_verify.sql`. Firefox is excluded until Fleet fixes `macos_firefox`.
4. Fleet fixes `macos_firefox` and merges the existing Firefox rows in a migration.

## Files
| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | Every test, how it runs and how it passes |
| [RESULTS.md](RESULTS.md) | One entry per test with the outcome, including the database tests |
| [EVIDENCE.md](EVIDENCE.md) | Generated index of the lab evidence |
| [NOTES.md](NOTES.md) | The handoff checked claim by claim, how ingestion works, what is not tested |
| [TRACKING.md](TRACKING.md) | Every related public issue, open and closed, and what tracks what |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| `sql/` | The scripts for the customer, in run order |
| `tests/app_suffix_test.go` | Go test that runs `sql/` inside Fleet's own test database and ingestion code |
| `tests/run-db-tests.sh` | Runs that test against any Fleet checkout: `tests/run-db-tests.sh ~/path/to/fleet` |
| `tests/macos_firefox.sql`, `tests/main_name.sql` | The two live queries used in L-1 |
| `reference/handoff-2026-10/` | The SQL from the October handoff, kept as received, run in C3 |
| `drafts/` | The GitHub bug and the customer reply. Adam posts them |
| `test-evidence/` | Raw output per test |

Status (2026-10-21): diagnosis done, all database tests pass on Fleet 4.90.3, 4.93.1 and `main`. Not yet run on the customer's data. Engineering review pending.
