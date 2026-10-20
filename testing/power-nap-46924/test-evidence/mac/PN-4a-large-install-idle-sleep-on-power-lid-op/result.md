# PN-4a: Large install idle sleep on power lid open

- **Started:** 2026-10-20T11:05:08Z
- **Objective:** Policy automation install while the laptop idle-sleeps on AC with the lid open (sleep 1 min)
- **Expected:** Unknown. Like PN-4 without the clamshell

## Steps and evidence
- `01-start.txt`: `cat /private/tmp/claude-502/-Users-adam-Library-Application-Support-Claude-scratch-workspaces-9a166397-56cf-4b`

Variant added 2026-10-20 while Adam was away: closing the lid needs someone at the laptop. Same as PN-4, but the laptop sleeps from idle (pmset sleep 1) with the lid open. Chrome deleted by a Fleet script at 13:04:39 local. The Chrome policy fails at the next policy check, about hourly.
