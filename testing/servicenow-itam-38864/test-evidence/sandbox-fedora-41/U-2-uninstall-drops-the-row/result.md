# U-2: Uninstall drops the row

- **Started:** 2026-10-20T09:02:07Z
- **Objective:** Remove hello, run the report
- **Expected:** No row for hello

## Steps and evidence
- `01-uninstall.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh uninstall`
- `02-rows-after-uninstall.txt`: `snap uninstall`
- `03-absent-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py absent hello /repo/testing/servicenow-ita`

## Result: PASS

Row gone at the next run

_Finished 2026-10-20T09:02:10Z_
