# Results: macOS Power Nap (#46924)

## D-1: Desk review of fleetd's download path (2026-10-19): INFO
- **Steps:** Read `orbit/pkg/installer/installer.go` on fleetdm/fleet `main` (aaa0d03) and searched `orbit/` and `pkg/` for `IOPMAssertion`, `caffeinate`, `PreventUserIdleSystemSleep` and `pmset`.
- **Found:**
  - fleetd logs "about to download software installer from URL" (line 440), tries the presigned URL, and on any error logs "downloading software installer from URL" and falls straight back to "about to download software installer from Fleet" (line 455). There is no retry of the URL and no resume.
  - If the Fleet download also fails, fleetd sets the "installer download failed" exit code (lines 462 to 467), and Fleet shows "Software installer download failed".
  - The only sleep assertion in fleetd is `caffeinate -dimsu` around swiftDialog (`orbit/pkg/swiftdialog/run.go:118`), used by setup experience. Nothing holds the Mac awake during software downloads, installs or scripts.
  - fleetd has a `pmset` table (`orbit/pkg/table/pmset`) that returns `pmset -g` output, so a report can read Power Nap settings across hosts.
- **Evidence:** `test-evidence/desk/D-1-fleetd-download-path/result.md`
- **Finding:** matches the mechanism in the thread. Needs a run on hardware (PN-1) to confirm.

## B-1: Baseline power settings (2026-10-20): INFO
- **Host:** MacBook Air Mac16,12, macOS 27.0.1, orbit 1.61.0, osquery 5.24.0, Fleet host 20 in Power Nap Lab, MDM on (manual).
- **Steps:** Fleet live queries on the fleetd `pmset` table (`getting = 'custom'`) and the osquery `battery` table.
- **Found:** on battery and AC, `powernap 1`, `tcpkeepalive 1`, `standby 1`, `hibernatemode 3`, `sleep 1` (system sleep after 1 minute idle). `womp 0` on battery, `1` on AC.
- **Evidence:** `test-evidence/mac/B-1-baseline-power-settings/`
- **Note:** `sleep 1` means the laptop idle-sleeps a minute after the last activity, even on AC with the lid open.

## C-1: Control install, lid open, on power (2026-10-20): PASS
- **Steps:** The laptop enrolled without Chrome or swiftDialog, so both policies failed on the first check and their automations queued at 10:31:21Z. Lid open on AC throughout. Logs read on the laptop through a Fleet script.
- **Found:**
  - Chrome: download 12:32:10 local, orbit restarted at 12:34:23 (SIGTERM about 90 s after MDM enrollment, then read its config from the profile), Fleet re-sent the install, download restarted 12:35:05, done 12:40:01, install exit 0 at 12:40:09.
  - swiftDialog: download 15 s, install exit 0 at 12:41:28.
  - Idle sleep at 12:43:15 local, 2 minutes after the last install. No sleep during a download.
- **Side finding:** an orbit restart mid-download drops the download with no error line. Fleet re-sends the install, so it finished.
- **Evidence:** `test-evidence/mac/C-1-control-install-lid-open-on-power/`

## PN-1: Large install, lid closed, battery (2026-10-20): PASS
- **Steps:** Chrome deleted by a Fleet script at 11:04:39Z. Charger unplugged and lid closed at 11:07:48Z. Refetch at 11:08:00Z so the policies ran at the next check-in. Lid opened at 13:00:34Z. Logs read through Fleet scripts after that.
- **Found (local time, UTC+2):**
  - DarkWakes with the lid closed lasted 2 to 10 s, about every 16 minutes, on battery.
  - 13:50:19 DarkWake: Fleet check-in, the Chrome policy fails, install queued.
  - 14:06:13 DarkWake (2 s): fleetd gets the install at 14:06:16 and starts the download from Fleet.
  - 14:23:25 DarkWake: at 14:23:26 fleetd logs `failed to download software installer ... copying from http stream to file: read tcp`. Fleet shows "Software installer download failed."
- **Finding:** reproduced. The download starts in one DarkWake and the TCP stream is dead at the next, 17 minutes later. Nothing holds the Mac awake (D-1). This is the mechanism the issue thread reports, on the Fleet download path, without presigned URLs.
- **Evidence:** `test-evidence/mac/PN-1-large-install-lid-closed-battery/`

## PN-6: What happens next (2026-10-20): PASS
- **Steps:** After PN-1, the lid opened at 13:00:34Z. A watcher logged Fleet every minute.
- **Found:** Fleet re-queued the install at the failure (12:23:26Z). It was not delivered in the two DarkWakes that followed (orbit logged "backing off"). After the lid opened, fleetd got the retry in 50 s, downloaded in 28 s and installed at 13:01:57Z. The policy passed at 13:02:17Z.
- **Finding:** one automatic retry. In the 37 minutes the lid stayed closed after the failure, it did not start in a DarkWake. It ran 50 s after a full wake. Whether it would start in a later DarkWake overnight is not tested.
- **Evidence:** `test-evidence/mac/PN-6-what-happens-next/`

## PN-2: Small install, lid closed, battery (2026-10-20): PARTIAL
- **Steps:** swiftDialog deleted by a Fleet script at 13:28:02Z (lid open, battery 74%). Lid closed and refetch at 13:28:33Z. Lid opened 08:11:55Z the next day. Logs read through Fleet scripts.
- **Found (local time, UTC+2):**
  - 16:28:30 DarkWake (6 s): policies run, the swiftDialog policy fails, install queued at 16:28:36, the same second the Mac sleeps.
  - 16:45 to 18:53: DarkWakes every 13 to 17 minutes, 2 to 8 s each. fleetd logs no install notification and no error.
  - 18:53 onward: fleetd logs `lookup fleet.mpc.ad: no such host` in DarkWakes, on and off all night. 76 DarkWakes overnight.
  - 19:37:36: the swiftDialog Fleet-maintained app updates to 3.1.1. The pending install disappears with no activity, and the title's status counts reset to 0.
  - Next morning: the policy still fails and nothing is queued again.
- **Finding:** not answered. The install never reached fleetd, so the small download never started. Rerun needed.
- **Side finding:** an FMA version update drops a pending install silently. The policy stays failing, so the automation does not queue the install again, and the host stays without the app.
- **Evidence:** `test-evidence/mac/PN-2-small-install-lid-closed-battery/`

## PN-2b: Small install, lid closed, battery, rerun (2026-10-21): in progress
- **Steps:** swiftDialog 3.1.1 reinstalled through Fleet with the lid open (installed 08:34:37Z), policy passes 08:35:40Z. swiftDialog deleted by a Fleet script at 08:36:09Z. Lid closed on battery and refetch at 08:50:09Z.
- **So far (2026-10-21T12:26:06Z):** check-ins at 09:06:29Z and 11:08:17Z, neither ran policies. Policies ran in a DarkWake at 11:25:15Z, 2 h 35 min after the refetch, and the install was queued. No check-in or install result since 11:25:19Z. The install is still pending.
- **Evidence:** `test-evidence/mac/PN-2b-small-install-lid-closed-battery-rerun/`
