# T-0: Baseline and osquery version

- **Started:** 2026-11-09T15:18:11Z
- **Objective:** Record the VM before any fake
- **Expected:** No JoinInfo subkeys, no MS-Organization-Access certificates

## Steps and evidence
- `01-os.txt`: `tools/qga.sh ids1 '(Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture | F`
- `02-fake-clear.txt`: `tools/qga.sh ids1 '& powershell -NoProfile -ExecutionPolicy Bypass -File C:\ids\fake-ids.ps1 clear'`

## Result: INFO

Windows 11 Pro 26300 arm64, osquery 5.24.1 (x64 MSI, SHA-256 matches the GitHub release digest). No JoinInfo subkeys or Entra certificates. 31 built-in Enrollments subkeys, none with MS DM Server.

_Finished 2026-11-09T15:21:12Z_
