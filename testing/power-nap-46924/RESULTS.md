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
