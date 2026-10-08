# D-12: Five-minute sync running for hours

- **Started:** 2026-10-07T18:44:49Z
- **Objective:** The 5-minute sync runs without Duo API errors or rate limits.
- **Expected:** No FAILED lines; a sync cycle about every 5 minutes.

## Steps and evidence
- `01-sync-log-stats.txt`: `python3 evidence/syncstats.py; echo; echo 'last 6 log lines:'; tail -6 duo/sync.log`

Full-day result pending: the loop is still running; this is a snapshot taken during the testing session.

## Result: PASS

Final numbers: 253 cycles from 2026-10-07 12:48 UTC to 2026-10-08 09:40 UTC (about 21 hours), median gap 300 s, longest gap 720 s, 0 failed. macOS and Linux synced every cycle; Windows was skipped (no hosts).

_Finished 2026-10-07T18:54:45Z_

- `02-terminal-sync-stats.png`: Sync stats at 2026-10-08 09:40 UTC (Terminal window capture on the Mac, added 2026-10-08). 253 cycles since 2026-10-07 12:48 UTC, median gap 300 s, max gap 720 s, 0 FAILED lines.
