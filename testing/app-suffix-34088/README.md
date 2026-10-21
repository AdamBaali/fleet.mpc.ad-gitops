# macOS software names ending in ".app" (fleetdm/fleet#34088, `customer-ufa`)

A customer sees macOS software versions named `Firefox.app` next to `Firefox`, and needs a safe cleanup. This folder holds the causes, the fixes made so far, the database fix, the product fixes needed, the SQL, and the evidence. It follows the method in `../_framework`.

No customer or person names in this folder. Refer to the customer by the `customer-ufa` label and to requests by public issue numbers. Internal links (Slack, support tickets, and call and meeting notes) live in `private/`, which git ignores.


## Why the ".app" rows exist

| Rows | Cause | Heals on its own? |
|---|---|---|
| Firefox and Firefox ESR | Fleet's `macos_firefox` query hard-codes `Firefox.app` and `Firefox ESR.app` (`server/service/osquery_utils/queries.go`, still in the 4.94.0 release branch). It runs on every Mac with the `parse_ini` table, which fleetd and the `fleetd_tables` extension both provide. We reproduced it on the lab Fleet (L-1) | No. A cleanup comes back on the next software report (C2) |
| Other apps | A custom `software_macos` detail query override, removed in September 2025 (#33140), sent `apps.name`, which keeps `.app` | Yes, when the host reports (C1). Rows on hosts offline since then stay |
| Other apps in Fleet's catalog (Premium) | The hourly Fleet-maintained app job renames old `.app` rows to the catalog name and keeps their checksum. They stop ending in `.app` and become a second row with the same name and version | Same as above. Rows on offline hosts stay as duplicates (C5) |
| Titles | Software ingestion never renames an existing title. The Fleet-maintained app job renames titles of catalog apps, but not Firefox, whose bundle ID is shared with Firefox ESR | Only for catalog apps other than Firefox |


## Fixes so far

| When | Where | Fix | What it left |
|---|---|---|---|
| 4.67 | Product | Names come from the app bundle (display name, bundle name). 4.67.0 renamed existing rows, and 4.67.1 removed that for database load | Old rows kept old names (#29053) |
| Sep 2025 | Customer | Removed the `software_macos` override (#33140) | `.app` rows already stored |
| 4.75.0 | Product | Name added to the macOS app checksum. Migration `20251015103505` recomputed those checksums in SQL. `run.sh` and `bundle_executable` names fixed (#34157, #34159) | Rows already stored |
| Oct 2025 | Customer, with Fleet | Contributor API script renamed `.app` titles (`PATCH /api/v1/fleet/software/titles/:id/name`) | Version rows, which that API call doesn't touch. #34088 was closed in November 2025 with no product change |
| 4.82.0 | Product | `.app` trim no longer strips other a's and p's (#34620, pull request #39563) | Nothing for this customer |
| 4.84.0 and later | Product | The hourly Fleet-maintained app job applies catalog names to titles, and by 4.90.3 to software rows, without changing checksums | Skips Firefox. Turns old `.app` rows of catalog apps into same-name duplicates |
| 4.90.0 | Product | One-shot migration renames mis-named titles from their sibling rows | Titles only |
| 4.91.0 | Product | Migration merges duplicate giflib rows (#36365) | giflib only (#52314) |


## The database fix (this folder)

Run after the customer's 4.93 upgrade. The upgrade runs the giflib merge migration, and `1_diagnose.sql` then reports what's left.

Fleet's own repair for duplicate rows, `mergeDuplicateSoftware` in migration `20260810160000_DedupeSoftwareChecksums` (4.91.0), is the model. It moves host links to the surviving row, then deletes the duplicate. The scripts apply the same steps.

1. `sql/1_diagnose.sql` is read-only. It sorts `.app` rows into recurring, offline only, and orphaned. It checks for overrides, checks the checksum formula against the customer's data, lists titles, counts same-name duplicates, and counts the #52314 duplicates.
2. `sql/4_titles.sql` renames `.app` titles. Software ingestion doesn't rename them back, so this holds for Firefox too.
3. `sql/2_plan.sql`, then `sql/3_apply_batch.sql` until nothing is pending, then `sql/5_verify.sql`, clean up rows linked only to offline hosts, in two passes:
   - Pass 1 merges each row still ending in `.app` into its twin without `.app`, found by checksum, or else into the one row with the same bundle ID and version that hosts use. When there's no twin, it renames the row and its checksum together.
   - Pass 2 merges same-name duplicates, like the ones the Fleet-maintained app job leaves, into the row hosts use today.
   Firefox is excluded from both. Each batch is one transaction, and Fleet keeps running.

Run each script with the `mysql` command-line client, which stops at the first error. Never use `--force` or a GUI that keeps going after an error. The scripts set READ COMMITTED so they don't block Fleet's software ingestion, which needs `binlog_format` ROW or MIXED, or the binary log off. Details in [NOTES.md](NOTES.md).

We ran the scripts in Fleet's test database with Fleet's ingestion code and the Fleet-maintained app job (C1 to C8), and through the `mysql` client against Fleet's schema (CL-1), on 4.90.3, 4.93.1, and `main`. An independent review ran them at 202,000 software rows with `EXPLAIN` and lock tests, and its findings are fixed. They haven't run on a real instance yet.


## The product fixes needed

1. `macos_firefox` sends `.app` names. Fix the query, and merge existing Firefox rows in a migration. Filed as [fleetdm/fleet#56168](https://github.com/fleetdm/fleet/issues/56168).
2. Rows with checksums from before 4.75.0 duplicate ([fleetdm/fleet#52314](https://github.com/fleetdm/fleet/issues/52314), open, no milestone). It may explain the customer's report of several software IDs for one version (TeamViewer). CHECK 7 will tell. Fleet repaired giflib only. C3 reproduces it. Draft comment adding the customer: [drafts/issue-comment-52314.md](drafts/issue-comment-52314.md).


## Related customer issues

See [TRACKING.md](TRACKING.md): every issue in this family, what each fixed, the two issues linked in the customer channel that don't fix the macOS name, and the customer's other open software inventory and vulnerability items.


## Files

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | Every test, how it runs and how it passes |
| [RESULTS.md](RESULTS.md) | One entry per test with the outcome, including the database tests |
| [EVIDENCE.md](EVIDENCE.md) | Generated index of the lab evidence |
| [NOTES.md](NOTES.md) | How Fleet ingests macOS software, the facts the scripts rely on, why each choice, and what isn't tested |
| [TRACKING.md](TRACKING.md) | Related public issues, open and closed, and what tracks what |
| [HANDOFF.md](HANDOFF.md) | State, next steps, and teardown |
| `sql/` | The scripts for the customer, in run order |
| `tests/app_suffix_test.go` | Go test that runs `sql/` inside Fleet's own test database and ingestion code |
| `tests/run-db-tests.sh` | Runs that test against any Fleet checkout: `tests/run-db-tests.sh ~/path/to/fleet` |
| `tests/run-client-smoke.sh`, `tests/fixture-client.sql` | Runs every script through the `mysql` client against Fleet's schema, the way the customer will |
| `tests/macos_firefox.sql`, `tests/main_name.sql` | The two live queries used in L-1 |
| `drafts/` | The customer update, the #help-customers review request, the GitHub bug, the #52314 comment, and the customer reply. Adam posts them |
| `test-evidence/` | Raw output per test |

Status (2026-10-21): all database tests and the client smoke test pass on Fleet 4.90.3, 4.93.1, and `main`. The scripts haven't run on the customer's data, and the engineering review is pending.
