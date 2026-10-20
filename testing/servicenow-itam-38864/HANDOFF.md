# Handoff: host and software fields for ServiceNow ITAM (#38864)

## State
Drafted, not applied: lab fleet (`fleets/servicenow-itam-lab.yml`), native reports (`lib/{macos,windows,linux}/reports/software-itam.reports.yml`) and `report_cap: 10000` in `default.yml`. Reports only: the `software_itam` extension was dropped on 2026-10-20 to keep the stopgap simple (NOTES.md, "Why no extension").

Test tooling in `scripts/`: ground truth helpers, on-host check, API runner, exporter prototype and compare. The unit and smoke tests pass against a fake Fleet API (`python3 -m unittest discover -s tests`). The PowerShell scripts have not been parsed or run: no PowerShell here. Nothing has run against the lab Fleet or a real host yet.

Linux sandbox run: native reports only, in fresh Ubuntu 24.04 and Fedora 41 containers. See RESULTS.md. Rerun with `CA_BUNDLE=<proxy CA, if any> OSQ_DIR=<osquery tarball root> scripts/run-sandbox-docker.sh`.

Blocked here, needs the lab: everything that reads Fleet (no API token in this environment), and every macOS and Windows test (no hosts reachable).

## Run order (2026-10-20)
1. **Morning setup.** Check the `LAB_CA` tunnel (root README). Add `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET`. Merge, let the apply run. Enroll the Mac, the Windows VM, the Fedora host and the Ubuntu host. Copy this repo onto each host.
2. **Smoke check.** `run-api-tests.sh setup <fleet_id>` and `host-local-check` on each host (S-1). Fix any SQL error before going on.
3. **Installs.** On each host, the gt install actions: `gt-macos.sh all-installs` then `fma-wait` and `appstore-wait`; `gt-windows.ps1 -Action msi-install` and `-Action exe-install`; `gt-linux.sh install`. Start `run-api-tests.sh watch ... present` for one app (A-3).
4. **Opens.** `gt-macos.sh open`, `gt-windows.ps1 -Action open`, `gt-linux.sh open`. Record facts (`gt-linux.sh facts`, `gt-windows.ps1 -Action facts`).
5. **First read, after the next hourly run.** `run-api-tests.sh all <fleet_id>`. This runs H, A-1, A-2 and compare.py for M-1, M-3, M-4, W-1 to W-3, L-1, L-3.
6. **Afternoon changes.** Upgrades (`dmg-upgrade`, `pkg-upgrade`, `-Action msi-upgrade`, `gt-linux.sh upgrade`). Uninstalls with `watch ... absent` (U-1), then reinstall (U-4).
7. **Second read, after the next run.** `run-api-tests.sh export <fleet_id>` for M-2, L-2, W-4, U-2, U-3, U-4. Run the exporter again an hour later with the same state file for A-4. Shut a host down for A-5.
8. **If time allows.** E-1 and E-2 on a ServiceNow developer instance.
9. **Write up.** Fill RESULTS.md and the "What the reports add" table in NOTES.md with results, not expectations.

## Running services (keep them on)
None yet.

## Teardown
- Uninstall the test apps: `gt-macos.sh uninstall`, remove Firefox, ITAMUnsigned and the App Store app; `gt-windows.ps1 -Action uninstall` and Notepad++; `gt-linux.sh uninstall`.
- Unenroll the test hosts or move them out of ServiceNow ITAM Lab.
- Remove `report_cap` from `default.yml`.
- Remove `fleets/servicenow-itam-lab.yml`, `fleets/servicenow-itam-lab/`, the `software-itam.reports.yml` files, the workflow env line and the repository secret.
- Delete the exporter state (`test-evidence/first_seen.json`) if the results don't need it.
- Delete the ServiceNow developer instance rows, if E-1 ran.

## Rules learned
- Keep customer and person names out of every file and commit. Use issue numbers. Pick test apps whose publisher is a company, so names don't reach the results.
- Check Fleet's own source and release notes before assuming a gap. Fleet already returns last opened on every OS, and 4.93.0 changed the report cap.
- `ev.sh` sets `HERE`. Scripts that source it keep their own folder in another variable.
