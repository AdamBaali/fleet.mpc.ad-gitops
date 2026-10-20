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
