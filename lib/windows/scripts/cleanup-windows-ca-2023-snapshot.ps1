<#
.SYNOPSIS
    Deletes the Windows Secure Boot CA 2023 snapshot state file.

.DESCRIPTION
    Removes:
      C:\ProgramData\Fleet\state\windows-ca-2023-snapshot.txt

    Use this to test the cold-import path: after deletion, re-run the
    windows-ca-2023 report. The snapshot-derived columns should read
    `run snapshot script` and the verdict falls back to `not_started`.

    The report keeps working without this file. Re-run
    snapshot-windows-ca-2023.ps1 to repopulate.

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

$statePath = 'C:\ProgramData\Fleet\state\windows-ca-2023-snapshot.txt'

Write-Output "=== Windows CA 2023 snapshot cleanup ==="
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
