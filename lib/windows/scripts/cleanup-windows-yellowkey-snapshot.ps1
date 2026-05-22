<#
.SYNOPSIS
    Deletes the Windows YellowKey snapshot state file.

.DESCRIPTION
    Removes:
      C:\ProgramData\Fleet\state\windows-yellowkey-snapshot.txt

    Use this to test the cold-import path: after deletion, re-run the
    windows-yellowkey report. The snapshot-derived columns should read
    `run snapshot script` and the verdict falls back to
    `affected_if_winre_on`.

    The report keeps working without this file. Re-run
    snapshot-windows-yellowkey.ps1 to repopulate.

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
