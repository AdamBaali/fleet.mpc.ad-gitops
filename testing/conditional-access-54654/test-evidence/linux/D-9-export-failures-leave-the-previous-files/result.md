# D-9: Export failures leave the previous files alone

- **Started:** 2026-10-07T18:43:47Z
- **Objective:** If a Fleet request fails, or a list would shrink by more than half, the export exits non-zero and does not replace the CSVs Duo is fed.
- **Expected:** Non-zero exit, no temp folder left behind, previous files unchanged; FORCE=true overrides the shrink guard.

## Steps and evidence
- `01-bad-report-id.txt`: `W=$(mktemp -d); sed -e 's#https://fleet.example.com#https://fleet.mpc.ad#' -e 's#<Windows-MachineGuid-report-I`
- `02-invalid-token.txt`: `W=$(mktemp -d); sed -e 's#https://fleet.example.com#https://fleet.mpc.ad#' -e 's#<Windows-MachineGuid-report-I`
- `03-shrink-guard.txt`: `W=$(mktemp -d); sed -e 's#https://fleet.example.com#https://fleet.mpc.ad#' -e 's#<Windows-MachineGuid-report-I`
- `04-test-harness-fixed-script.txt`: `bash tests/test_export_script.sh fleet/docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh 2>&1 | tail -3`
- `05-test-harness-original-script.txt`: `git -C fleet show pr-54346:docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh > /tmp/export-original.sh;`

## Result: **PASS**

Bad report ID and invalid token both exit non-zero and leave the previous CSVs untouched with no temp folder; the shrink guard refuses a 300-to-0 drop and FORCE=true overrides it. The 27-check harness passes on the fixed script; the original PR script fails 6 of the new checks.

_Finished 2026-10-07T18:43:56Z_
