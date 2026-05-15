<#
.SYNOPSIS
    Deletes Windows snapshot state files written by snapshot-windows-*.ps1.

.DESCRIPTION
    Removes:
      C:\ProgramData\Fleet\state\windows-ca-2023-snapshot.txt
      C:\ProgramData\Fleet\state\windows-yellowkey-snapshot.txt

    Use this to test the cold-import path: after deletion, re-run
    the windows-ca-2023 and windows-yellowkey reports. The
    snapshot-derived columns should read `run snapshot script` and
    the verdicts fall back to `not_started` / `affected_if_winre_on`.

    Reports keep working without these files. Re-running the
    matching snapshot-windows-*.ps1 repopulates them.

.NOTES
    Exit codes:
      0 = Cleanup complete (files deleted or already absent)
      1 = Deletion failed for one or more files
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

$stateDir = 'C:\ProgramData\Fleet\state'
$targets  = @(
    (Join-Path $stateDir 'windows-ca-2023-snapshot.txt'),
    (Join-Path $stateDir 'windows-yellowkey-snapshot.txt')
)

Write-Output "=== Windows snapshot cleanup ==="
Write-Output ""

$failed = 0
foreach ($path in $targets) {
    $name = Split-Path $path -Leaf
    if (-not (Test-Path $path)) {
        Write-State $name 'already absent'
        continue
    }
    try {
        Remove-Item -Path $path -Force
        Write-State $name 'deleted'
    } catch {
        Write-State $name "FAILED: $($_.Exception.Message)"
        $failed++
    }
}

Write-Output ""
if ($failed -gt 0) {
    Write-Output "Done with $failed failure(s)."
    exit 1
}

Write-Output "Done. Re-run reports to verify cold-import behaviour."
exit 0
