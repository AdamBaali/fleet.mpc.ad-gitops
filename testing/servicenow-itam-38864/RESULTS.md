# Results: host and software fields for ServiceNow ITAM (#38864)

## Ground truth
The gt scripts write every install, open, upgrade, reinstall and uninstall with its UTC time to `ground-truth/<host>.tsv` as it happens. Summarize them here after the run.

| Host | OS | App | Method | Installed (UTC) | Opened (UTC) | Upgraded (UTC) | Uninstalled (UTC) |
|---|---|---|---|---|---|---|---|
| sandbox ubuntu-2404 | Ubuntu 24.04 container | hello 2.10-3build1 | apt | 07:50:52 | | 07:50:57 (reinstall, one version in the repo) | 07:51:01, reinstalled 07:51:05, removed 07:51:09 |
| sandbox fedora-41 | Fedora 41 container | hello 2.12.2 | dnf | 07:51:33 | | 07:51:40 (downgrade then upgrade) | 07:51:43, reinstalled 07:51:47, removed 07:51:49 |

All times 2026-10-20 UTC. Files: `ground-truth/ubuntu-2404.tsv`, `ground-truth/fedora-41.tsv`.

## Verdicts
`run-api-tests.sh` appends every scripted verdict to `test-evidence/api/results.tsv`, and compare.py writes `test-evidence/api/verdicts/verdicts.md`. Copy the outcome of each test below with the evidence folder.

## Linux sandbox run (2026-10-20, reports only)
The extension was dropped on 2026-10-20 to keep the stopgap simple, so this run covers the native reports only. An earlier run the same morning also tested the extension; its evidence is in git history (commit b6b9edc).

`scripts/run-sandbox-docker.sh` ran `scripts/run-sandbox-linux.sh` in fresh Ubuntu 24.04 and Fedora 41 containers. Real: the report SQL from `lib/linux/reports/software-itam.reports.yml`, osquery 5.14.1, the package manager, and the ground truth. Not covered: Fleet ingestion, the API and the exporter, since there is no Fleet server here. Containers hold 129 (Ubuntu) and 138 (Fedora) packages, fewer than a real host. Evidence: `test-evidence/sandbox-ubuntu-2404/`, `test-evidence/sandbox-fedora-41/`, indexed in `EVIDENCE.md`.

| Test | Ubuntu 24.04 (DEB) | Fedora 41 (RPM) | What it showed |
|---|---|---|---|
| L-2 / L-1 install date and publisher | PASS | PASS | Install date within 0 seconds of the recorded install. Publisher "Ubuntu Developers" (after dropping the list address) and "Fedora Project" |
| L-2u / L-1u upgrade and reinstall | PASS | PASS | The date moved to the upgrade, then to the reinstall, on both. See findings |
| U-2 uninstall | PASS | PASS | Row gone at the next run |
| Coverage | INFO | INFO | Install date on 100% of rows. Publisher on 100% (Ubuntu) and 99.3% (Fedora) |
| L-3 last used | NOT-RUN | NOT-RUN | Needs a Fleet server. Mount options and osquery version saved |

### Findings
1. **On Linux the report date is the last change, not the first install.** DEB `list_changed` and RPM `install_time` both moved on every upgrade and reinstall. Label them "installed (this version)" in ServiceNow. For "first installed", use the exporter's `first_seen`, which keeps the first time the exporter saw the package on the host.
2. **DEB publisher is a maintainer, not a company.** "Ubuntu Developers" is the distribution team for most packages. The exporter drops the list address. This matches the Linux publisher note on #37087.
3. **The report SQL works as written.** Both Linux queries ran clean on both distros with no extension and nothing extra installed.

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
