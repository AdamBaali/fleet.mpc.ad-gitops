<#
.SYNOPSIS
    Sets the YellowKey mitigation opt-in marker on a Windows host.

.DESCRIPTION
    Writes the registry value that mitigate-windows-yellowkey.ps1
    requires before it will strip autofstx.exe from the WinRE image's
    Session Manager BootExecute (Microsoft's CVE-2026-45585 mitigation):

      HKLM\SOFTWARE\Fleet\YellowKey\AllowMitigation = 1 (DWORD)

    Designed to be run via Fleet's scripts feature against a label-
    targeted subset of hosts, so admins can opt hosts in without
    touching each one by hand. Idempotent.

    To clear the marker manually:
      Remove-ItemProperty -Path HKLM:\SOFTWARE\Fleet\YellowKey `
        -Name AllowMitigation

.OUTPUTS
    Structured key:value output to stdout.

.NOTES
    Exit codes:
      0 = Marker set (action taken or already set)
      4 = Write failed or post-write readback mismatch
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== Set YellowKey AllowMitigation marker ==="
Write-Output ""

$markerPath = "HKLM:\SOFTWARE\Fleet\YellowKey"
$markerName = "AllowMitigation"

$current = (Get-ItemProperty -Path $markerPath -Name $markerName -ErrorAction SilentlyContinue).$markerName
if ($null -ne $current -and $current -eq 1) {
    Write-Output "OK: marker already set."
    Write-State "AllowMitigation" "1 (already set)"
    exit 0
}

if (-not (Test-Path $markerPath)) {
    New-Item -Path $markerPath -Force | Out-Null
}

try {
    Set-ItemProperty -Path $markerPath -Name $markerName -Value 1 -Type DWord -Force
} catch {
    Write-Output "FAIL: could not write marker: $($_.Exception.Message)"
    Write-State "AllowMitigation" "write_failed"
    exit 4
}

$current = (Get-ItemProperty -Path $markerPath -Name $markerName -ErrorAction SilentlyContinue).$markerName
if ($current -eq 1) {
    Write-Output "OK: marker set."
    Write-State "AllowMitigation" "1"
    exit 0
}

Write-Output "FAIL: marker write reported success but readback shows $current."
Write-State "AllowMitigation" "readback_mismatch"
exit 4
