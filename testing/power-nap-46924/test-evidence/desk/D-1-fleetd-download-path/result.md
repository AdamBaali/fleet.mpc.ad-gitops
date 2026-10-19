# D-1: fleetd's download path and sleep assertions

- **Date:** 2026-10-19
- **Objective:** Check the mechanism reported in fleetdm/fleet#46924 against fleetd's code before testing on hardware.
- **Source:** fleetdm/fleet `main` at aaa0d03.

## Steps and evidence
- `orbit/pkg/installer/installer.go:438-468`: download from the presigned URL first. On error, log it and fall back to the Fleet server at once. If that fails, return `fleet.ExitCodeInstallerDownloadFailed` and "Installer download failed".
- `git grep -i -e IOPMAssertion -e caffeinate -e PreventUserIdleSystemSleep -e pmset -- orbit/ pkg/`: the only sleep assertion is `/usr/bin/caffeinate -dimsu -w <pid>` around swiftDialog (`orbit/pkg/swiftdialog/run.go:112-124`). The `pmset` hits are the CIS table extension (`orbit/pkg/table/pmset`).
- `server/fleet/software_installer.go:583`: the "Software installer download failed." text Fleet shows.

## Result: INFO

fleetd doesn't keep the Mac awake for downloads, installs or scripts, and doesn't retry or resume a failed presigned URL download. This fits the thread's report. Not tested on hardware yet.
