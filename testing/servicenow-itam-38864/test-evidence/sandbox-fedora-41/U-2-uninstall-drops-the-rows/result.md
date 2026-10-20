# U-2: Uninstall drops the rows

- **Started:** 2026-10-20T07:37:59Z
- **Objective:** Remove hello, read both again
- **Expected:** No row in the native report or software_itam

## Steps and evidence
- `01-uninstall.txt`: `/repo/testing/servicenow-itam-38864/scripts/gt-linux.sh uninstall`
- `02-rows-after-uninstall.txt`: `snap uninstall`
- `03-check.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py absent hello /repo/testing/servicenow-ita`

## Result: PASS

Both rows gone at the next query

_Finished 2026-10-20T07:38:03Z_
