# Handoff: host and software fields for ServiceNow ITAM (#38864)

## State
Drafted, not applied: lab fleet (`fleets/servicenow-itam-lab.yml`), native reports (`lib/{macos,windows,linux}/reports/software-itam.reports.yml`), extension report (`lib/all/reports/software-itam-extension.reports.yml`), extension policies and installers (`lib/<os>/policies/software-itam-extension.policies.yml`, `lib/<os>/scripts/install-software-itam-extension.*`) and `report_cap: 10000` in `default.yml`.

Test tooling in `scripts/`: ground truth helpers, on-host check, API runner, exporter prototype and compare. The 28 unit and smoke tests pass against a fake Fleet API (`python3 -m unittest discover -s tests`). The PowerShell scripts have not been parsed or run: no PowerShell here. Nothing has run against the lab Fleet or a real host.

## Run order (2026-10-20)
1. **Morning setup.** Check the `LAB_CA` tunnel (root README). Add `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET`. Merge, let the apply run. Enroll the Mac, the Windows VM, the Fedora host and the Ubuntu host. Copy this repo onto each host.
2. **Smoke check.** `run-api-tests.sh setup <fleet_id>` and `host-local-check` on each host (S-1). Fix any SQL error before going on.
3. **Extension rollout.** Wait for the extension policy and its installer, then `run-api-tests.sh ext-policy` (X-1). Run `host-local-check` again for X-2 and timings.
4. **Installs.** On each host, the gt install actions: `gt-macos.sh all-installs` then `fma-wait` and `appstore-wait`; `gt-windows.ps1 -Action msi-install` and `-Action exe-install`; `gt-linux.sh install`. Start `run-api-tests.sh watch ... present` for one app (A-3).
5. **Opens.** `gt-macos.sh open`, `gt-windows.ps1 -Action open`, `gt-linux.sh open`. Record facts (`gt-linux.sh facts`, `gt-windows.ps1 -Action facts`).
6. **First read, after the next hourly run.** `run-api-tests.sh all <fleet_id>`. This runs H, X-1, X-3, A-1, A-2 and compare.py for M-1, M-3, M-4, W-1 to W-3, L-1, L-3, X-4, X-5.
7. **Afternoon changes.** Upgrades (`dmg-upgrade`, `pkg-upgrade`, `-Action msi-upgrade`, `gt-linux.sh upgrade`). Restart fleetd and note `first_seen` (X-8). Uninstalls with `watch ... absent` (U-1, U-2), then reinstall (X-7). Remove the extension for X-10.
8. **Second read, after the next run.** `run-api-tests.sh export <fleet_id>` for M-2, L-2, X-6, X-7, U-3. Run the exporter again an hour later for A-4. Reboot for X-8 and shut a host down for X-11.
9. **If time allows.** E-1 and E-2 on a ServiceNow developer instance.
10. **Write up.** Fill RESULTS.md, the C tests, and the "What the reports add" table in NOTES.md with results, not expectations.

## Running services (keep them on)
None yet.

## Teardown
- On each host, remove the extension: the binary (`/var/osquery/extensions/software_itam.ext` on macOS and Linux, `C:\Program Files\osquery\extensions\software_itam-<hash>.ext.exe` on Windows), its line in `extensions.load` (`/var/osquery/` on macOS, `/etc/osquery/` on Linux, `C:\Program Files\osquery\` on Windows), and `software_itam_state.json` next to the binary. Restart fleetd.
- Uninstall the test apps: `gt-macos.sh uninstall`, remove Firefox, ITAMUnsigned and the App Store app; `gt-windows.ps1 -Action uninstall` and Notepad++; `gt-linux.sh uninstall`.
- Unenroll the test hosts or move them out of ServiceNow ITAM Lab.
- Remove `report_cap` from `default.yml`.
- Remove `fleets/servicenow-itam-lab.yml`, `fleets/servicenow-itam-lab/`, the `software-itam*.reports.yml` files, the extension policies and installers, the workflow env line and the repository secret.
- Delete the exporter state (`test-evidence/first_seen.json`) if the results don't need it.
- Delete the ServiceNow developer instance rows, if E-1 ran.

## Rules learned
- Keep customer and person names out of every file and commit. Use issue numbers. Pick test apps whose publisher is a company, so names don't reach the results.
- Check Fleet's own source and release notes before assuming a gap. Fleet already returns last opened on every OS, and 4.93.0 changed the report cap.
- `ev.sh` sets `HERE`. Scripts that source it keep their own folder in another variable.
