<#
.SYNOPSIS
    Deletes the Windows YellowKey snapshot state file.

.DESCRIPTION
    Removes:
      C:\ProgramData\Fleet\state\windows-yellowkey-snapshot.txt

    Forces the report to fall back to native-only verdicts on the next
    run. Use this to test the cold-import path, or to force a fresh
    snapshot capture on the next run of snapshot-windows-yellowkey.ps1.

    The report keeps working without this file. snapshot_status will
    read `missing` and the verdict falls back to the native-only set
    (not_affected, mitigated, bitlocker_off, exposed, unknown).

.NOTES
    Exit codes:
      0 = File deleted or already absent
      1 = Deletion failed
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

$statePath = 'C:\ProgramData\Fleet\state\windows-yellowkey-snapshot.txt'

Write-Output "=== Windows YellowKey snapshot cleanup ==="
Write-Output ""

if (-not (Test-Path $statePath)) {
    Write-State (Split-Path $statePath -Leaf) 'already absent'
    Write-State 'State' 'already_absent'
    exit 0
}

try {
    Remove-Item -Path $statePath -Force
    Write-State (Split-Path $statePath -Leaf) 'deleted'
    Write-State 'State' 'deleted'
    exit 0
} catch {
    Write-Output "FAIL: $($_.Exception.Message)"
    Write-State 'State' 'delete_failed'
    exit 1
}
