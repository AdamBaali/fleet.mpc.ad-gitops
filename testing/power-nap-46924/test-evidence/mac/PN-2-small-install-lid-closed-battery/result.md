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
- `03-fleet-watch-final.txt`: `cat fleet-watch-final.txt`
- `04-orbit-log.txt`: `cat orbit-log.txt`
- `05-pmset-sleep-wake.txt`: `cat pmset-log.txt`
- `06-fma-title-after.txt`: `cat fma-title.txt`

Final (logs read through Fleet scripts after the lid opened at 10:11:55 local on 2026-10-21). Local time is UTC+2.

| Local time | pmset -g log | orbit.stderr.log | Fleet |
|---|---|---|---|
| 15:28:35 | Clamshell Sleep, battery 74% | | refetch 13:28:33Z |
| 16:13:00 | DarkWake 3 s | | check-in 14:13:04Z, no policy run |
| 16:28:30 | DarkWake 6 s, sleep 16:28:36 | nothing | policies run 14:28:36Z, swiftDialog policy fails, install queued |
| 16:45 to 18:53 | DarkWakes every 13 to 17 min, 2 to 8 s each | no install notification, no error | no check-in |
| 18:53 onward | DarkWakes continue (76 overnight) | ERR lookup fleet.mpc.ad: no such host, on and off all night | |
| 19:37:36 | | | swiftDialog FMA updated to 3.1.1 (uploaded_at 17:37:36Z). The pending install is gone, with no activity |
| 10:11:55 next day | Wake, lid | | queue empty, policy still fails, nothing re-queued |

- The install never reached fleetd. The small download never started, so PN-2's question is not answered.
- Side finding: a Fleet-maintained app version update drops a pending install silently and resets the title's status counts. The policy stays failing, so the automation does not queue the install again. The host stays without swiftDialog until the policy passes and fails again.
- Side finding: from 18:53 local, DNS lookups for the Fleet server failed in DarkWakes.
- Between 16:28 and 18:53 local, fleetd logged nothing: no install notification and no error.
- Rerun needed.

## Result: PARTIAL

Install queued in a DarkWake but never reached fleetd. An FMA update to 3.1.1 at 17:37Z dropped it silently and nothing re-queued it. Small download not tested, rerun needed

_Finished 2026-10-21T08:31:43Z_
