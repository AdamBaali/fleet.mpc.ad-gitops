# Tracking: ".app" software names (`customer-ufa`)

Checked 2026-10-21. Every issue below was read in full, with its comments, through the GitHub API. Release facts come from Fleet's release tags and `CHANGELOG.md`.

Every `.app` issue was closed when an ingestion fix shipped or a title rename was done. Nothing tracks the Firefox name, and the open issue for duplicate rows (#52314) doesn't carry the customer's label.


## The gap

| What needs tracking | Tracked by | State |
|---|---|---|
| `macos_firefox` sends `Firefox.app` and `Firefox ESR.app` | Nothing. #50077 and #50090 don't change it (see below) | To file: [drafts/github-issue-firefox-app.md](drafts/github-issue-firefox-app.md) |
| Existing `.app` version rows and titles | Nothing since #34088 closed | Covered by the same draft (migration ask) and the scripts here |
| Rows with old checksums duplicate (may explain the customer's TeamViewer duplicates) | #52314, open, `bug`, `#g-supply-chain`, no milestone | Add `customer-ufa` and the comment in [drafts/issue-comment-52314.md](drafts/issue-comment-52314.md) |
| Customer request for the scripts | Internal support ticket, on hold | See `private/` |


## Closed issues in this family

| Issue | Closed | Milestone | `customer-ufa` | What happened | Covers stored rows? |
|---|---|---|---|---|---|
| #29053 Existing macOS software names aren't fixed on ingestion | 2025-09-26 | 4.73.3 | Yes | 4.67.0 renamed existing rows on ingestion, and 4.67.1 removed that for database load. The issue was closed without a migration | No |
| #33140 Software missing after removing detail query override | 2025-09-26 | 4.73.3 | Yes | Apps went missing after the customer removed its `software_macos` override. That override sent `apps.name`, the source of the 2025 `.app` rows | No |
| #33468 Ingestion fails for versions with the same bundle ID | 2025-10-10 | 4.73.5 | Yes | Only one of several versions with the same bundle ID was linked to the host during rename handling | No |
| #23999 Missing vulnerabilities when a macOS app name changes | 2025-10-15 | none | Yes | Closed as theoretical, with no fix of its own. Follow-ups #34157, #34159, and #34282 | No |
| #34157 Steam games ingested as `run.sh` | 2025-10-17 | 4.75.0 | Yes | Falls back to the trimmed file name when `bundle_executable` is `run.sh` | No |
| #34159 Counterintuitive names from `bundle_executable` | 2025-10-17 | 4.75.0 | Yes | Ingestion renames the listed apps by bundle ID | No |
| #28788 Apps with duplicate bundle IDs missing | 2025-10-17 | 4.75.0 | Yes | Apps that share a bundle ID each get a software row, under one title | No |
| #34088 Some software isn't trimming the ".app" | 2025-11-08 | 4.76.0 | Yes | Closed after the title rename script, with no product change. Version rows were never fixed. An engineer called a rename migration risky | No |
| #34620 Trim removes leading and trailing a's and p's | 2026-03-12 | 4.82.0 | No | Only a trailing `.app` is trimmed now. Pull request #39563 | No |
| #42445 FMA: Firefox.app name and icon | 2026-07-15 | 4.89.0 | No | Title name when the Firefox Fleet-maintained app is added. Shows `Firefox.app` arriving on a fresh instance | Only titles with that installer |
| #49682 Error when adding Firefox and Firefox ESR to one fleet | 2026-09-02 | 4.91.0 | No | Firefox and Firefox ESR share `org.mozilla.firefox` | No |


## Related Fleet changes

| Version | Change | Effect here |
|---|---|---|
| 4.75.0 | `ComputeRawChecksum` puts the name last for all software. Migration `20251015103505` recomputed checksums for macOS apps with a bundle ID only | Precedent for renaming the name and checksum together. Other rows kept old checksums (#52314) |
| 4.84.0 | Fleet-maintained app names overwrite title names | Titles of catalog apps get the catalog name |
| 4.90.3 or earlier | The hourly `ReconcileMaintainedAppSoftwareNames` job also renames `software` rows to the catalog name, without changing the checksum. Skips bundle IDs shared by two apps, like Firefox, unless the title has that app's installer | Old `.app` rows of catalog apps become same-name duplicates. Test C5 |
| 4.90.0 | One-shot title migration for login helper names | Titles only |
| 4.91.0 | Migration `20260810160000_DedupeSoftwareChecksums` merges duplicate giflib Homebrew rows (#36365) | Covers giflib only. The model for the merge in `3_apply_batch.sql`. Runs during `fleet prepare db` on the customer's upgrade from 4.90.3 |


## Customer's other open software inventory and vulnerability items

| Issue | State | Milestone | Relation to this work |
|---|---|---|---|
| #52314 Duplicate entries for software with old checksums | Open | none | Two rows for one version. The issue says pre-4.76.0. The `fleet-v4.74.0` and `fleet-v4.75.0` tags show the formula changed in 4.75.0. `1_diagnose.sql` CHECK 7 sizes it |
| #36365 Duplicate CVE entries for giflib 5.2.2 | Closed | 4.91.0 | Fixed by migration, giflib only. The customer was only asked for read-only queries |
| #45602 `software_cve` rows deleted when the feed sync fails | Closed | 4.87.0 | Fleet deleted and recreated `software_cve` rows after a bad feed. Not related to names |
| #47911 More granular false-positive handling in `cpe_translations.json` | Open | none | Skip rules apply to the whole software (name and source). Asks for version-scoped rules |
| #51822 CVE filtering in false-positive filters | Open | 5.2.0 | Sub-issue of #47911. A comment adds version-range scoping |
| #46054 User-driven vulnerability suppression rules | Open | none | Admin-defined CVE suppression. Related to #47911, which asks for narrower rules managed by Fleet |
| #35046 Research: report vulnerabilities for all software | Open | none | Asks how to catch software with improper names |
| #54258 SHA-256 for Python and npm packages | Open | 5.1.0 | Hashes feed the customer's Santa rules |
| #48884 SHA-256 for Homebrew | Closed | 4.93.0 | Shipped in 4.93, API only. One hash per Mach-O file in the keg's `bin`. Needs the 4.93 fleetd or `fleetd_tables` extension |
| #49666 "Last opened" for Homebrew and npm (follows #43571) | Open | none | #43571 was closed after the customer asked to pause it |
| #41982 Software architecture in the API | Open | none | Not prioritized |
| #38662 Observability alerts for agent health, inventory, and vulns | Open | none | Customer still testing the suggested workarounds (incomplete as of the Oct 8 meeting) |


## Linked in the customer channel, but they don't fix the macOS name

On Oct 12 the customer was told that either of these "should fix the issue". Neither changes the macOS `Firefox.app` name. The 4.94.0 release branch (Oct 20) still hard-codes it in `macos_firefox`.
- #50090 (open, 4.94.0): Firefox 153.0 matched 60 CVEs because Fleet compared `153.0` as older than `153.0.0`. The fix (#55056) changes version comparison only, passed QA, and ships in 4.94.0. The customer's 4.93 upgrade won't have it, so Firefox 153.0 false positives stay until 4.94.0.
- #50077 (open, 4.95.0): on Windows, Fleet-maintained apps whose name has the version in the middle (like Firefox ESR) link to the wrong title. Windows only. Its test plan says macOS is unaffected. No pull request yet.


## Open issues that help spot duplicates

- #18634 Surface `bundle_identifier` in the UI, and #15938 find software by bundle identifier (open, `customer-ufa`).
