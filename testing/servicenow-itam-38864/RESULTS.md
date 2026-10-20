# Results: host and software fields for ServiceNow ITAM (#38864)

## Ground truth
The gt scripts write every install, open, upgrade, reinstall and uninstall with its UTC time to `ground-truth/<host>.tsv` as it happens. Summarize them here after the run.

| Host | OS | App | Method | Installed (UTC) | Opened (UTC) | Upgraded (UTC) | Uninstalled (UTC) |
|---|---|---|---|---|---|---|---|
| sandbox ubuntu-2404 | Ubuntu 24.04 container | hello 2.10-3build1 | apt | 07:37:02 | | 07:37:12 (reinstall, one version in the repo) | 07:37:18, reinstalled 07:37:23 |
| sandbox fedora-41 | Fedora 41 container | hello 2.12.2 | dnf | 07:37:44 | | 07:37:55 (downgrade then upgrade) | 07:37:59, reinstalled 07:38:04 |

All times 2026-10-20 UTC. Files: `ground-truth/ubuntu-2404.tsv`, `ground-truth/fedora-41.tsv`.

## Verdicts
`run-api-tests.sh` appends every scripted verdict to `test-evidence/api/results.tsv`, and compare.py writes `test-evidence/api/verdicts/verdicts.md`. Copy the outcome of each test below with the evidence folder.

## Linux sandbox run (2026-10-20)
`scripts/run-sandbox-docker.sh` ran `scripts/run-sandbox-linux.sh` in fresh Ubuntu 24.04 and Fedora 41 containers. Real: the pinned extension download and checksum, the installer, `/etc/osquery/extensions.load`, osquery 5.14.1 loading the extension from that file, the package manager, and the ground truth. Not real: no fleetd (systemctl and systemd-run are shims that log calls), no Fleet server, so nothing here covers ingestion, the API or the exporter. Containers hold 129 (Ubuntu) and 138 (Fedora) packages, far fewer than a real host. Evidence: `test-evidence/sandbox-ubuntu-2404/`, `test-evidence/sandbox-fedora-41/`, indexed in `EVIDENCE.md`.

| Test | Ubuntu 24.04 (DEB) | Fedora 41 (RPM) | What it showed |
|---|---|---|---|
| X-1 installer | PASS | PASS | Pinned binary downloaded and matched its SHA-256, root-owned 0755, listed once in `/etc/osquery/extensions.load`, restart scheduled with `systemd-run --on-active=30` |
| X-1b second run | PASS | PASS | Nothing downloaded, no duplicate loader line, no restart |
| X-1c wrong checksum | PASS | PASS | Exit 6, the good binary stayed in place |
| X-2 autoload | PASS | PASS | osquery loaded the extension from the default autoload file with no `--extension` flag. All 12 columns present |
| L-2 / L-1 install date | PASS | PASS | Native and extension both within 0 seconds of the recorded install |
| X-5 publisher | PASS | PASS | DEB: "Ubuntu Developers" plus the list address (the exporter should strip `<...>`). RPM: "Fedora Project" |
| X-3 rows and coverage | PASS | PASS | Same row count as the native inventory. Install date 100% on both paths. Publisher 100% (DEB), 99.3% (RPM) |
| X-8 first_seen across restart | PASS | PASS | Same value in two osquery processes for every row. Reboot not tested |
| X-9 cost | INFO | INFO | 0.65 s and 42 MB (Ubuntu), 0.72 s and 42 MB (Fedora) for a full query. Small package counts, so not representative of a real host |
| L-2u upgrade | PASS | PASS | See findings |
| U-2 uninstall | PASS | PASS | Both rows gone at the next query |
| X-7 reinstall | PASS | PASS | first_seen kept the first sighting on both |
| L-3 last used | NOT-RUN | NOT-RUN | Needs a Fleet server. Mount options and osquery version saved |

### Findings
1. **DEB: only the extension keeps the first install date.** After a reinstall and a second reinstall, the native `list_changed` moved each time (07:37:12, 07:37:23). The extension kept 07:37:02 from `dpkg.log`. For an audit asking "first installed", the native DEB value is a last changed date.
2. **RPM: neither path keeps the first install date.** RPM stores the install time of the version on disk. After a downgrade and upgrade, and after a reinstall, both the native report and the extension moved to the latest install (07:37:55, then 07:38:04). The extension matches the native value but doesn't improve it. `first_seen` still kept 07:37:47. Label RPM dates "installed (this version)", or use `first_seen` for "first installed".
3. **DEB publisher is a maintainer, not a company.** "Ubuntu Developers" is the distribution team for most packages. That matches #37087's note on Linux publisher quality.

## S-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## H-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## H-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## H-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## H-4: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## H-5: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## H-6: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## M-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## M-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## M-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## M-4: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## M-5: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## W-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## W-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## W-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## W-4: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## L-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## L-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## L-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-4: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-5: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-6: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-7: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-8: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-9: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-10: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## X-11: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## C-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## C-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## C-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## C-4: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## U-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## U-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## U-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## A-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## A-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## A-3: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## A-4: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## E-1: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 

## E-2: (2026-10-20): NOT-RUN
- **Steps:** 
- **Expected:** see TEST_PLAN.md
- **Actual:** 
- **Evidence:** 
- **Finding:** 
