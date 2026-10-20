# Session context: ServiceNow ITAM stopgap (#38864)

Handoff from a cloud Claude Code session to a local one, 2026-10-20. Paste or point a new local session at this file to pick up where it stopped. No customer or person names: refer to the request by issue number.

## The ask
A customer needs installed software for every host in ServiceNow ITAM for an NYDFS audit in March. macOS is required (their ServiceNow shows only Windows). For each app: first installed and last run. Hourly sync. Most hardware is already in ServiceNow.

The built-in connector (#38864), install date (#54912) and publisher (#54914) are P2 for Fleet 5.1.0. All three are open, unassigned and have no PRs. 5.1.0 targets Dec 25 and engineering expects January, with no commitment. The agreed plan: the customer solutions architect team builds a stopgap; the customer moves to the built-in connector when it ships.

## Decisions made
1. **Reports only, no osquery extension** (2026-10-20). Nothing installed on hosts beyond fleetd. An extension (`software_itam`) was built and tested, then dropped to keep it simple. Its code stays on branch `software-itam` in AdamBaali/fleet-extensions (commit `1c520ee`), unused. Its test evidence is in this repo's history at commit `b6b9edc`.
2. **Native osquery tables only.** No fleetd tables: `codesign` gives only the Team ID, which Fleet already ingests.
3. **Collect only what Fleet doesn't return.** Fleet's software API already gives name, version, install path and `last_opened_at` on every OS (macOS from Spotlight, Windows from Prefetch, Linux from file access times; DEB needs osquery 5.19+). Fleet stores Windows and RPM publisher as `vendor` but the host software API doesn't return it.
4. **`report_cap: 10000`** in `default.yml`. Fleet 4.93 raises the cap to the host count, which only helps reports with one row per host. These reports return one row per app.
5. **Label every date with its source.** The exporter adds `first_seen` (first time the exporter saw the app on the host), the only stable "first installed" on Linux.
6. Keep the stopgap thin and disposable. Spend spare effort on getting #54912 and #54914 built.

## Where everything is
Repo: AdamBaali/fleet.mpc.ad-gitops, `main`. PR #30 (https://github.com/AdamBaali/fleet.mpc.ad-gitops/pull/30, branch `servicenow-itam-38864`) merged 2026-10-20 08:14 UTC. Work on `main` or a new branch from it, not the merged branch.

| Path | What |
|---|---|
| `fleets/servicenow-itam-lab.yml`, `fleets/servicenow-itam-lab/README.md` | Lab fleet "ServiceNow ITAM Lab", reports only |
| `lib/macos/reports/software-itam.reports.yml` | Install date (Spotlight date added, bundle creation), publisher (`signature.authority`), pkg receipts |
| `lib/windows/reports/software-itam.reports.yml` | `programs` install date and publisher, Uninstall key write time (`registry`, `type = 'subkey'`) |
| `lib/linux/reports/software-itam.reports.yml` | RPM install time and vendor, DEB file list mtime and maintainer |
| `default.yml` | `report_cap: 10000` (remove with the lab) |
| `fleets/power-nap-lab.yml` | Also fixed here: its script listed under `controls.scripts`, which `run_script` requires |
| `.github/workflows/workflow.yml` | Adds `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET` |
| `testing/servicenow-itam-38864/TEST_PLAN.md` | All tests: S, H-1..H-6 (host fields), M, W, L, U-1..U-4, A-1..A-5, E-1, E-2 |
| `testing/servicenow-itam-38864/RESULTS.md`, `EVIDENCE.md` | Results so far and the evidence index |
| `testing/servicenow-itam-38864/HANDOFF.md` | Run order for the lab and teardown |
| `testing/servicenow-itam-38864/NOTES.md` | What each OS gives, exporter design, risks, sandbox findings |
| `testing/servicenow-itam-38864/scripts/` | Ground truth (`gt-*.sh`, `gt-windows.ps1`), on-host checks, `fleet-api.sh`, `run-api-tests.sh`, `fleet_itam_export.py` (exporter), `compare.py`, sandbox runners |
| `testing/servicenow-itam-38864/share/STATUS.md` | Internal summary: ask, issues and progress, gaps |
| `testing/servicenow-itam-38864/share/export-software-inventory-to-servicenow.md` | Draft Fleet guide for other customers (fleetdm/fleet `articles/`, category guides). Author and date are TODO. Publish after lab tests pass |
| `testing/servicenow-itam-38864/share/FEATURE_REQUEST.md`, `feature-request-link.txt` | Draft feature request (per-host report cap, the one unfiled gap) and evidence comments for #54912 and #54914. Not posted |

## Results so far
- **Linux sandbox, reports only** (fresh Ubuntu 24.04 and Fedora 41 containers, osquery 5.14.1, no Fleet server): all PASS. Install date within 0 s of the recorded install. Publisher correct. Rows drop on uninstall.
- **Finding:** on Linux, DEB `list_changed` and RPM `install_time` move to the latest upgrade or reinstall. Label them "installed (this version)" and use `first_seen` for first installed.
- **Finding:** DEB publisher is a maintainer team ("Ubuntu Developers"). The exporter strips the list address.
- Exporter: 29 Python tests pass against a fake Fleet API (`cd scripts && python3 -m unittest discover -s tests`).
- **Not run yet:** every macOS and Windows test, every test that reads the lab Fleet (H, A, E, M, W), last opened (L-3). PowerShell scripts never parsed (no PowerShell in the cloud box).

## Next steps
1. **Fix the failing apply.** The merge's apply (Actions run 39391993323) failed with `each item in 'secrets' must have a 'secret' key containing an ASCII string value`: an enroll secret is empty. The Power Nap push before it (run 39269633593) failed the same way, plus a `controls.scripts` error that PR #30 fixed. Add both repository secrets if missing: `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET` and `FLEET_POWER_NAP_LAB_ENROLL_SECRET`. Then re-run "Apply latest configuration to Fleet" (workflow_dispatch). Until it passes, the lab Fleet has neither the Power Nap nor the ServiceNow ITAM config. Check the `LAB_CA` tunnel first (root README, Known issue).
2. Enroll a Mac, the Windows 11 VM, a Fedora host and an Ubuntu host into "ServiceNow ITAM Lab". Follow `HANDOFF.md` run order.
3. For API tests, create an API-only Observer user and export `FLEET_URL` and `FLEET_API_TOKEN` (or a `SECRETS_ENV` file). Never commit the token.
4. Fill `RESULTS.md`, rebuild `EVIDENCE.md` with `testing/_framework/bin/build-evidence-index.py`.
5. After tests: confirm the label `customer-rosner` and file the feature request (link in `share/feature-request-link.txt`), post the #54912 and #54914 comments, contribute the exporter to fleetdm/fleet `docs/solutions/api-scripts/` and open the guide PR.

## Local commands
```bash
git clone https://github.com/AdamBaali/fleet.mpc.ad-gitops && cd fleet.mpc.ad-gitops

# Exporter unit tests
(cd testing/servicenow-itam-38864/scripts && python3 -m unittest discover -s tests)

# Linux sandbox re-run (needs Docker and an extracted osquery Linux tarball)
curl -LO https://pkg.osquery.io/linux/osquery-5.14.1_1.linux_x86_64.tar.gz
mkdir osq && tar xzf osquery-5.14.1_1.linux_x86_64.tar.gz -C osq
OSQ_DIR=$PWD/osq testing/servicenow-itam-38864/scripts/run-sandbox-docker.sh

# GitOps static checks with Fleet's own skill
git clone --depth 1 https://github.com/fleetdm/fleet ../fleet
python3 ../fleet/.claude/skills/fleet-gitops/scripts/validate.py .
```
The validator shows two expected FAILs (YellowKey and rpm-ostree extension tables) and none from this work.

## Repo rules (from CLAUDE.md)
Short declarative sentences, active voice, sentence case headings, no em dashes, no filler words, say "hosts". Comments explain why. Never commit secrets. Nothing is pushed or posted automatically without the owner's go-ahead. No customer or person names in files or commits.
