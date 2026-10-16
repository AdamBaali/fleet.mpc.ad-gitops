# D-12: Five-minute sync running for hours

- **Started:** 2026-10-07T18:44:49Z
- **Objective:** The 5-minute sync runs without Duo API errors or rate limits.
- **Expected:** No FAILED lines; a sync cycle about every 5 minutes.

## Steps and evidence
- `01-sync-log-stats.txt`: `python3 evidence/syncstats.py; echo; echo 'last 6 log lines:'; tail -6 duo/sync.log`

Full-day result pending: the loop is still running; this is a snapshot taken during the testing session.

## Result: **PASS** (closed 2026-10-16)

Snapshot: about 70 sync cycles over six hours, median gap 300 s, no FAILED lines and no Duo API errors or rate limits. The full day will be recorded tomorrow.

_Finished 2026-10-07T18:54:45Z_

- `02-terminal-sync-stats.png`: Sync stats at 2026-10-08 09:40 UTC (Terminal window capture on the Mac, added 2026-10-08). 253 cycles since 2026-10-07 12:48 UTC, median gap 300 s, max gap 720 s, 0 FAILED lines.

## Final result (2026-10-16)
Loop ran 2026-10-07 12:48 UTC to 2026-10-11 15:45 UTC: 723 distinct sync cycles, median gap 300 s (the 64200 s maximum is the Mac asleep, not a sync failure). 696 macOS and 696 Linux uploads, no Duo API errors or rate limits. Four `export FAILED` lines, all transient network errors reaching `fleet.mpc.ad` (connection reset, two SSL timeouts, one DNS failure); the next cycle recovered each time. Closed as PASS. The guide now recommends a daily sync, so the 5-minute result is supporting evidence only.
