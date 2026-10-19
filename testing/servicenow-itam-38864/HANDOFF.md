# Handoff: software fields for ServiceNow ITAM (#38864)

## State
Plan, reports (`lib/{macos,windows,linux}/reports/software-itam.reports.yml`) and lab fleet (`fleets/servicenow-itam-lab.yml`) drafted, not applied. Linux report SQL ran clean in osquery 5.14.1. macOS and Windows column names checked against the osquery specs, not run on a host.

## Next steps (2026-10-20)
1. Morning: add the repository secret `FLEET_SERVICENOW_ITAM_LAB_ENROLL_SECRET`, merge, let the apply run (S-1). Check the `LAB_CA` tunnel first (see the root README).
2. Enroll the Mac, the Windows VM, a Fedora host and an Ubuntu host. Run each report live once to catch SQL errors.
3. Install and open the test apps, writing every time in RESULTS.md. Then wait for the hourly run.
4. Midday: M-1, M-3, M-4, W-1, W-2, W-3, L-1, L-2, L-3, A-2.
5. Afternoon: update the test apps (M-2, L-2 second half), M-5 after two runs, A-1 and A-3.
6. If time allows: E-1 on a ServiceNow developer instance.
7. Fill the "What each OS can give" table in NOTES.md with results, not expectations.

## Running services (keep them on)
None yet.

## Teardown
- Unenroll the test hosts or move them out of ServiceNow ITAM Lab.
- Remove `fleets/servicenow-itam-lab.yml`, `fleets/servicenow-itam-lab/`, the three `software-itam.reports.yml` files, the workflow env line and the repository secret.
- Delete the ServiceNow developer instance rows, if E-1 ran.

## Rules learned
- Keep customer and person names out of every file and commit. Use issue numbers.
