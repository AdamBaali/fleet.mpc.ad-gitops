# D-3: Export script writes the three CSVs

- **Started:** 2026-10-07T18:43:07Z
- **Objective:** The guide's export script (with the PR fixes) writes macos.csv, windows.csv and linux.csv with a device_id header.
- **Expected:** Header plus one UUID per Fleet host for macOS and Linux; Windows has no hosts.

## Steps and evidence
- `01-run-export.txt`: `W=$(mktemp -d); sed -e 's#https://fleet.example.com#https://fleet.mpc.ad#' -e 's#<Windows-MachineGuid-report-I`
- `02-script-version.txt`: `git -C fleet log --oneline -1 -- docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh | cat; shellcheck fl`

## Result: **PASS**

The export (guide script plus temp-file and shrink-guard fix) wrote macos.csv and linux.csv with one UUID each and header-only windows.csv; no temp folder was left behind.

_Finished 2026-10-07T18:43:09Z_

- `03-terminal-export-csvs.png`: Re-run of the guide export script against the lab Fleet (Terminal window capture on the Mac, added 2026-10-08). Shows macos.csv (1 host), windows.csv (0, header only) and linux.csv (1 host).
