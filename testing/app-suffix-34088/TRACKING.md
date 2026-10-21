# Tracking: ".app" software names (`customer-ufa`)

Checked 2026-10-21 against the GitHub API. Every issue that tracked this was closed when an ingestion fix shipped. Nothing tracks the rows already stored, and nothing tracks the Firefox override. The label has 85 open issues and none is a bug.

## The gap
| What needs tracking | Tracked by | State |
|---|---|---|
| `macos_firefox` sends `Firefox.app` and `Firefox ESR.app` | Nothing | To file: [drafts/github-issue-firefox-app.md](drafts/github-issue-firefox-app.md) |
| Existing `.app` version rows and titles | Nothing since #34088 closed | Covered by the same draft (migration ask) and the scripts here |
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
| 4.91.0 | Merged duplicate giflib Homebrew rows in a migration | Precedent for merging duplicate software rows in a migration |

## Open issues worth linking to the draft
- #50090 Firefox false-positive CVE match (open, 4.94.0). Another Firefox ingestion edge, different cause.
- #18634 Surface `bundle_identifier` in the UI, and #15938 find software by bundle identifier (open, `customer-ufa`). Both help spot `.app` duplicates.
