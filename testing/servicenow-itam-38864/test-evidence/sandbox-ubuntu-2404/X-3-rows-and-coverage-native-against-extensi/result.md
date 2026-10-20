# X-3: Rows and coverage: native against extension

- **Started:** 2026-10-20T07:37:05Z
- **Objective:** Count rows, install dates and publishers on the whole host
- **Expected:** Row counts within 5%. Coverage recorded for C-1 and C-2

## Steps and evidence
- `01-coverage.txt`: `python3 /repo/testing/servicenow-itam-38864/scripts/sandbox_check.py coverage /repo/testing/servicenow-itam-38`

## Result: PASS

Extension row count within 5% of the native inventory. Coverage in the output

_Finished 2026-10-20T07:37:05Z_
