# R-1b: proposed script, partner ID and empty-list guard

- **Date:** 2026-10-09
- **Objective:** Check the corrected script and that it refuses an empty Fleet list
- **Expected:** Lint clean; exit 1 and no changes when Fleet returns 0 hosts

## Steps and evidence
- `script-under-test.sh` and `guide-script-edits.diff`: the draft script with (1) partner ID without the leading C, (2) a guard that refuses an empty Fleet list, (3) FLEET_URL and customer ID from the environment.
- `01-lint.txt`: `bash -n` and `shellcheck` clean.
- `02-empty-list-guard.txt`: mock Fleet returns no hosts: the script exits 1 and changes nothing. Without the guard the draft script would mark every matched Google device UNMANAGED (E-13).

## Result: PASS
