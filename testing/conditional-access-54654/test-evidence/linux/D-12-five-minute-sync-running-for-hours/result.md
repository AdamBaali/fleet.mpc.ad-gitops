# D-12: Five-minute sync running for hours

- **Started:** 2026-10-07T18:44:49Z
- **Objective:** The 5-minute sync runs without Duo API errors or rate limits.
- **Expected:** No FAILED lines; a sync cycle about every 5 minutes.

## Steps and evidence
- `01-sync-log-stats.txt`: `python3 evidence/syncstats.py; echo; echo 'last 6 log lines:'; tail -6 duo/sync.log`

Full-day result pending: the loop is still running; this is a snapshot taken during the testing session.

## Result: **PARTIAL**

Snapshot: about 70 sync cycles over six hours, median gap 300 s, no FAILED lines and no Duo API errors or rate limits. The full day will be recorded tomorrow.

_Finished 2026-10-07T18:54:45Z_
