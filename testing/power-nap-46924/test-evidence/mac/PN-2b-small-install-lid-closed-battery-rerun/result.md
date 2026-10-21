# PN-2b: Small install lid closed battery rerun

- **Started:** 2026-10-21T08:36:07Z
- **Objective:** PN-2 again: policy automation installs swiftDialog while the laptop sleeps with the lid closed on battery
- **Expected:** Unknown: may finish inside one DarkWake

## Steps and evidence
- `01-start.txt`: `cat start.txt`

Rerun of PN-2, which never reached fleetd. Setup with the lid open: swiftDialog 3.1.1 reinstalled through Fleet (queued 08:33:57Z, installed 08:34:37Z), refetch 08:34:42Z, policy passes at 08:35:40Z. swiftDialog deleted by a Fleet script at 08:36:09Z (battery 74%).

Lid closed on battery, reported by the tester at about 2026-10-21T08:50:08Z. Refetch requested at 2026-10-21T08:50:09Z.
- `02-fleet-watch-so-far.txt`: `cat fleet-watch-so-far.txt`

In progress at 2026-10-21T12:25:56Z (lid closed on battery since 08:50:08Z):
- Check-ins only at 09:06:29Z and 11:08:17Z. Neither ran policies.
- 11:25:15Z policies ran in a DarkWake, 2 h 35 min after the refetch. The swiftDialog policy fails and the install is queued at 11:25:14Z.
- No check-in and no install result since 11:25:19Z, about an hour. The install is still pending in Fleet.
- Next: open the lid when the watcher ends (12:50Z) and read the orbit and pmset logs.
- `03-fleet-watch-final.txt`: `cat fleet-watch-final.txt`
- `04-failed-install-result.txt`: `cat failed-install-result.txt`
- `05-orbit-and-pmset.txt`: `cat orbit-and-pmset.txt`
- `06-activities.txt`: `cat activities.txt`

Final (logs read through Fleet scripts after the lid opened). Local time is UTC+2. IP addresses masked.

| Local time | pmset -g log | orbit.stderr.log | Fleet |
|---|---|---|---|
| 10:50:08 | Lid closed on battery | | refetch 08:50:09Z |
| 11:06, 13:08 | | | check-ins, no policy run |
| 13:25:11 | DarkWake 2 s, sleep 13:25:13 | | policies 11:25:15Z, swiftDialog policy fails, install queued 11:25:14Z |
| 13:41:48, 13:52:10 | DarkWakes 2 s and 6 s | nothing | |
| 14:10:02 | DarkWake 2 s, sleep 14:10:04 | 14:10:05 install notification, download from Fleet starts | |
| 14:26:46 | next DarkWake | 14:26:46 ERR failed to download: copying from http stream to file | failed_install 12:26:47Z, retry queued |
| before 14:49 | lid opened (exact time not pulled) | 14:49:06 retry, download 3 s, install exit 0 at 14:49:13 | installed 12:49:13Z |

The small download does not finish inside a DarkWake. fleetd starts it one second after macOS logs Entering Sleep, the same as PN-1, so the size of the package does not matter. The stream is dead at the next DarkWake 17 minutes later. With the lid open the same pkg (dialog-3.1.1) downloads in 3 s. The retry after the failure waited for the lid to open, as in PN-6.

## Result: PASS

Answered: the small install fails like the large one. Download starts 1 s after Entering Sleep, read error at the next DarkWake 17 min later. Retry installed after the lid opened (14:49:13 local)

_Finished 2026-10-21T12:50:06Z_
