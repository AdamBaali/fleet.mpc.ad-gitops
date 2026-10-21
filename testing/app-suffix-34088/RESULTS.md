# Results: ".app" software name cleanup

## L-1: Firefox name from a fleetd Mac (2026-10-21): PASS
- **Steps:** On the lab Fleet (4.93.0), live queries on MPC-Adam: `parse_ini` table present, `tests/macos_firefox.sql`, `tests/main_name.sql`.
- **Expected:** The override gives `Firefox.app`, the main query gives `Firefox`.
- **Actual:** As expected. `parse_ini` exists. The override returns `Firefox.app` 157.0.1, the main query returns `Firefox` for the same app. The lab stores `Mozilla Firefox` because this fleet has the Firefox Fleet-maintained app, and the hourly name reconcile renames by that installer link.
- **Evidence:** `test-evidence/lab/L-1-firefox-name-sent-by-a-fleetd-mac/`
- **Finding:** Fleet produces `Firefox.app` today on every Mac with `parse_ini`. Without a Firefox installer on the title, the reconcile skips the shared bundle ID and the name stays `Firefox.app`. Fleet's own test expects this (`server/datastore/mysql/maintained_apps_test.go`, "A host reports Firefox via osquery (name "Firefox.app")").

## C1: Self-heal when a host reports (2026-10-21): PASS
- **Steps:** A host reports `Slack.app` 4.40, then `Slack` 4.40. Run `SyncHostsSoftware`, `CleanupSoftwareTitles`, `SyncHostsSoftwareTitles`.
- **Actual:** The second report drops the `.app` link and links `Slack`. The orphaned `.app` row is deleted. The title stays `Slack.app`.
- **Evidence:** `test-evidence/db/<version>/go-test.txt`
- **Finding:** Rows only stay while their hosts stay offline or keep sending `.app`. Titles always stay.

## C2: Firefox comes back after a manual merge (2026-10-21): PASS
- **Steps:** A fleetd host reports `Firefox.app`, a plain host reports `Firefox`: two version rows for one app. Merge by hand, then the fleetd host reports again.
- **Actual:** The `Firefox.app` row is created again and linked after one report.
- **Finding:** No cleanup of Firefox lasts until `macos_firefox` changes. The plan excludes `org.mozilla.firefox`.

## C3: Handoff SQL as written (2026-10-21): FAIL (for the handoff SQL)
- **Steps:** Run `reference/handoff-2026-10/0_preflight.sql`, `1_preview.sql`, `2_execute.sql` on the fixture.
- **Actual:** 0 and 1 run. `2_execute.sql` creates its backup tables, runs STEP 1 (writes `last_opened_at`), then stops at STEP 2: `Error 1064 ... near 'LIMIT 1000'`. MySQL has no `LIMIT` on a multi-table `DELETE` or `UPDATE`. STEP 3, 4, 5 and 6 have the same problem. Nothing runs in a transaction, so a stop leaves partial changes.
- **Evidence:** `test-evidence/db/<version>/C3-handoff-*.txt`
- **Finding:** Do not send the handoff SQL.

## C4: Diagnose buckets (2026-10-21): PASS
- **Steps:** Build the fixture (override-era rows on offline hosts, today's rows on online hosts, one orphan, one online host still on `Slack.app`). Run `sql/1_diagnose.sql`.
- **Actual:** orphaned 1, offline only 2, recurring 1 (Slack.app), recurring Firefox 1. Checksum check: 8 matching, 0 mismatched.
- **Evidence:** `test-evidence/db/<version>/C4-diagnose.txt`

## C5: Cleanup, then ingestion (2026-10-21): PASS
- **Steps:** Same fixture. `2_plan.sql`, `3_apply_batch.sql` until nothing is pending, `4_titles.sql`. Then an offline host comes back and a new host reports, through `UpdateHostSoftware`. Then `5_verify.sql` and the vulnerabilities cron functions.
- **Actual:**
  - Plan: 1 merge (Zoom.app), 1 rename (Notion.app). Slack.app (online host) and Firefox.app (excluded) left alone.
  - Zoom.app deleted. Both offline hosts point at Zoom. The host linked to both kept the newer `last_opened_at`. Its installed path is not doubled.
  - Notion.app keeps its id, is named Notion, and its checksum equals `Software.ComputeRawChecksum` for Notion.
  - After both reports: no new software rows, the new host links to the renamed row, no duplicate versions, no `.app` titles, Notion counts 2 hosts.
- **Evidence:** `test-evidence/db/<version>/C5-*.txt`

## Versions
C1 to C5 pass on `fleet-v4.90.3` (customer production), `fleet-v4.93.1` (customer's next upgrade) and `main` at e1cf388cca. One folder per version under `test-evidence/db/`.

## N-1: Negative control (2026-10-21): PASS
- **Steps:** A copy of `sql/` with `s.version, s.source` swapped in the checksum.
- **Actual:** C4 and C5 fail. CHECK 4 reports mismatches, and the plan selects nothing, because it only takes rows whose stored checksum matches the formula. A wrong formula fails safe. A first attempt that swapped `extension_for` and `extension_id` still passed, because both are empty for macOS apps.
- **Evidence:** `test-evidence/db/negative-control.txt`
