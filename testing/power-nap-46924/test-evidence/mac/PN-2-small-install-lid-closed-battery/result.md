# PN-2: Small install lid closed battery

- **Started:** 2026-10-20T13:28:04Z
- **Objective:** Policy automation installs swiftDialog (small pkg) while the laptop sleeps with the lid closed on battery
- **Expected:** Unknown: may finish inside one DarkWake

## Steps and evidence
- `01-start.txt`: `cat start.txt`

swiftDialog deleted by a Fleet script at 13:28:02Z (lid open, battery 74%). Lid closed next, then a refetch so the policy runs at the next DarkWake check-in, as in PN-1.

Lid closed and on battery, reported by Adam at about 2026-10-20T13:28:32Z. Refetch requested at 2026-10-20T13:28:33Z.
