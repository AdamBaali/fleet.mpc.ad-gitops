# PN-2: Small install lid closed battery

- **Started:** 2026-10-20T13:28:04Z
- **Objective:** Policy automation installs swiftDialog (small pkg) while the laptop sleeps with the lid closed on battery
- **Expected:** Unknown: may finish inside one DarkWake

## Steps and evidence
- `01-start.txt`: `cat start.txt`

swiftDialog deleted by a Fleet script at 13:28:02Z (lid open, battery 74%). Lid closed next, then a refetch so the policy runs at the next DarkWake check-in, as in PN-1.

Lid closed and on battery, reported by the tester at about 2026-10-20T13:28:32Z. Refetch requested at 2026-10-20T13:28:33Z.
- `02-fleet-watch-so-far.txt`: `cat fleet-watch-so-far.txt`

In progress at 2026-10-20T15:26:39Z (lid still closed, battery):
- 14:13:04Z first check-in after the lid closed. Policies did not run (as at 11:17Z in PN-1).
- 14:28:36Z policies ran in a DarkWake. swiftDialog policy fails, install queued (pending_install).
- No check-in and no install result since 14:28:42Z, about 50 minutes. Fleet cannot tell whether fleetd started the download until fleetd reports back or the lid opens.
- Next: wait for a result or the watcher end (16:28Z), then open the lid and read the orbit and pmset logs.
