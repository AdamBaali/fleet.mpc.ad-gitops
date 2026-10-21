# PN-2b: Small install lid closed battery rerun

- **Started:** 2026-10-21T08:36:07Z
- **Objective:** PN-2 again: policy automation installs swiftDialog while the laptop sleeps with the lid closed on battery
- **Expected:** Unknown: may finish inside one DarkWake

## Steps and evidence
- `01-start.txt`: `cat start.txt`

Rerun of PN-2, which never reached fleetd. Setup with the lid open: swiftDialog 3.1.1 reinstalled through Fleet (queued 08:33:57Z, installed 08:34:37Z), refetch 08:34:42Z, policy passes at 08:35:40Z. swiftDialog deleted by a Fleet script at 08:36:09Z (battery 74%).

Lid closed on battery, reported by the tester at about 2026-10-21T08:50:08Z. Refetch requested at 2026-10-21T08:50:09Z.
