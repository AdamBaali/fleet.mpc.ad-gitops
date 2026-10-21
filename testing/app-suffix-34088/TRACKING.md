# Tracking: ".app" software names (`customer-ufa`)

Checked 2026-10-21 against the GitHub API. Every `.app` issue was closed when an ingestion fix shipped. Nothing tracks the Firefox override, and the open issue for duplicate rows (#52314) does not carry the customer's label.


## The gap

| What needs tracking | Tracked by | State |
|---|---|---|
| `macos_firefox` sends `Firefox.app` and `Firefox ESR.app` | Nothing | To file: [drafts/github-issue-firefox-app.md](drafts/github-issue-firefox-app.md) |
| Existing `.app` version rows and titles | Nothing since #34088 closed | Covered by the same draft (migration ask) and the scripts here |
| Rows with checksums from before 4.75.0 duplicate (may explain the customer's TeamViewer duplicates) | #52314, open, `bug`, `#g-supply-chain`, no milestone | Add `customer-ufa` and the comment in [drafts/issue-comment-52314.md](drafts/issue-comment-52314.md) |
| Customer request for the scripts | Internal support ticket, on hold | See `private/` |


## Closed issues in this family

| Issue | Closed | Milestone | `customer-ufa` | What it fixed | Covers stored rows? |
|---|---|---|---|---|---|
| #29053 Existing macOS software names aren't fixed on ingestion | 2025-09-26 | 4.73.3 | Yes | Renames on ingestion after the 4.67 name change | No |
| #33140 Software missing after removing detail query override | 2025-09-26 | 4.73.3 | Yes | Missing apps after the customer removed its `software_macos` override, the source of the 2025 `.app` rows | No |
| #33468 Ingestion fails for versions with the same bundle ID | 2025-10-10 | 4.73.5 | Yes | Ingestion error | No |
| #23999 Missing vulnerabilities when a macOS app name changes | 2025-10-15 | none | Yes | Vulnerability matching after renames | No |
| #34157 Steam games ingested as `run.sh` | 2025-10-17 | 4.75.0 | Yes | Name source for Steam games | No |
| #34159 Counterintuitive names from `bundle_executable` | 2025-10-17 | 4.75.0 | Yes | Name source order | No |
| #28788 Apps with duplicate bundle IDs missing | 2025-10-17 | 4.75.0 | Yes | Apps that share a bundle ID now ingest | No |
| #34088 Some software isn't trimming the ".app" | 2025-11-08 | 4.76.0 | Yes | Closed after the title rename script. Version rows were never fixed | No |
| #34620 Trim removes leading and trailing a's and p's | 2026-03-12 | 4.82.0 | No | Over-trimming. Fixed by pull request #39563 | No |
| #42445 FMA: Firefox.app name and icon | 2026-07-15 | 4.89.0 | No | Title name when the Firefox Fleet-maintained app is added | Only titles with that installer |
| #49682 Error when adding Firefox and Firefox ESR to one fleet | 2026-09-02 | 4.91.0 | No | Shared bundle ID for installers | No |


## Related Fleet changes

| Version | Change | Effect here |
|---|---|---|
| 4.75.0 | Migration `20251015103505` recomputed macOS app checksums in SQL, with the name | Precedent for renaming name and checksum together |
| 4.84.0 | Fleet-maintained app names overwrite title names | Fixes titles only where the bundle ID maps to one app, so not Firefox |
| 4.92.0 | The hourly name reconcile renames `software` rows by primary key, name only (an earlier form existed by 4.90.1) | Fleet renames `software.name` in SQL. Not for Firefox without its installer |
| 4.90.0 | One-shot title migration for login helper names | Titles only. Picks the shared prefix of sibling names, which can turn `Firefox.app` plus `Firefox` into `Firefox` for titles that had both at upgrade |
| 4.91.0 | Migration `20260810160000_DedupeSoftwareChecksums` merges duplicate giflib Homebrew rows (#36365) | The model for the merge in `3_apply_batch.sql`. Runs on the customer's upgrade from 4.90.3, with no manual steps |


## Customer's other open software inventory and vulnerability items

| Issue | State | Milestone | Relation to this work |
|---|---|---|---|
| #52314 Duplicate entries for software with old checksums (issue says pre-4.76.0, tags show 4.75.0) | Open | none | Same class: two rows for one version. `1_diagnose.sql` CHECK 7 sizes it. Not labeled `customer-ufa` yet |
| #36365 Duplicate CVE entries for giflib 5.2.2 | Closed, 4.91.0 | 4.91.0 | Fixed by migration on upgrade. The customer's 4.93 upgrade runs it |
| #45602 `software_cve` rows deleted when the feed sync fails | Closed | 4.87.0 | The customer cleaned their database after it. Not related to names |
| #47911 More granular false-positive handling in `cpe_translations.json` | Open | none | Name and source matching. Two version rows for one app double matches |
| #51822 CVE filtering in false-positive filters | Open | 5.2.0 | Child of #47911 |
| #46054 User-driven vulnerability suppression rules | Open | none | Same need as #47911 |
| #35046 Research: report vulnerabilities for all software | Open | none | Name quality feeds CPE matching |
| #54258 SHA-256 for Python and npm packages | Open | 5.1.0 | Hashes feed the customer's Santa rules |
| #48884 SHA-256 for Homebrew | Closed | 4.93.0 | Shipped. Customer asked whether it covers several binaries per package |
| #49666 "Last opened" for Homebrew and npm (follows #43571) | Open | none | Paused at the customer's request |
| #41982 Software architecture in the API | Open | none | Low priority for the customer |
| #38662 Observability alerts for agent health, inventory, vulns | Open | none | Customer testing after GitOps is stable |


## Not related, though linked in the customer channel

- #50077 (Windows names with versions match the wrong title) and #50090 (Firefox CVE false positive on 153.0) are other customers' bugs with different causes. Neither changes Firefox's name.


## Open issues that help spot duplicates

- #18634 Surface `bundle_identifier` in the UI, and #15938 find software by bundle identifier (open, `customer-ufa`).
