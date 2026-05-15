<#
.SYNOPSIS
    Inspects YellowKey exposure on a Windows host. Read-only.

.DESCRIPTION
    Reports the signals osquery cannot surface from the report alone:
      - WinRE enabled state (from `reagentc /info`)
      - BitLocker key protector types per volume (TPM-only vs TPM+PIN
        vs Recovery, etc.) -- Get-BitLockerVolume, not osquery
      - OS version and YellowKey exposure verdict
      - Opt-in marker state for mitigate-windows-yellowkey.ps1

    READ-ONLY. Makes no changes.

.NOTES
    Intended use:
      - Confirm hosts flagged by the windows-yellowkey report
      - Decide which hosts get the AllowMitigation marker set
      - Sanity-check before running mitigate / unmitigate

    Exit code: always 0 unless PowerShell itself errors. Output is the
    deliverable.
#>

$ErrorActionPreference = 'Continue'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-32} : {1}" -f $Label, $Value)
}

Write-Output "=== Windows YellowKey verification ==="
Write-Output ""

# --- OS ---
Write-Output "--- OS ---"
try {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    Write-State "OS" $os
    $verdict = if     ($os -match 'Windows 10')                                                       { 'not_affected (Win10)' }
               elseif ($os -match 'Windows 11' -or $os -match 'Server 2022' -or $os -match 'Server 2025') { 'affected_if_winre_on' }
               else                                                                                  { 'unknown_os' }
    Write-State "YellowKey exposure" $verdict
} catch {
    Write-State "OS" "FAILED: $($_.Exception.Message)"
}

# --- WinRE state ---
Write-Output ""
Write-Output "--- WinRE ---"
try {
    $infoText = (& reagentc /info 2>&1) | Out-String
    if ($infoText -match 'Windows RE status:\s*(Enabled|Disabled)') {
        Write-State "WinRE status" $Matches[1]
    } else {
        Write-State "WinRE status" "could not parse reagentc output"
    }
    if ($infoText -match 'Windows RE location:\s*(\S.*)') {
        Write-State "WinRE location" $Matches[1].Trim()
    }
} catch {
    Write-State "WinRE status" "FAILED: $($_.Exception.Message)"
}

# --- BitLocker volumes ---
Write-Output ""
Write-Output "--- BitLocker volumes ---"
try {
    $volumes = Get-BitLockerVolume -ErrorAction Stop
    if ($null -eq $volumes -or $volumes.Count -eq 0) {
        Write-State "BitLocker" "no volumes returned"
    }
    foreach ($v in $volumes) {
        Write-Output "  Volume: $($v.MountPoint)"
        Write-State "  Protection status" $v.ProtectionStatus
        Write-State "  Volume status"     $v.VolumeStatus
        Write-State "  Encryption %"      $v.EncryptionPercentage
        $kpTypes = @($v.KeyProtector | ForEach-Object { $_.KeyProtectorType })
        $kpStr   = if ($kpTypes.Count -gt 0) { $kpTypes -join ', ' } else { '(none)' }
        Write-State "  Key protectors"    $kpStr
        Write-Output ""
    }
} catch {
    Write-State "BitLocker" "FAILED: $($_.Exception.Message)"
}

# --- Opt-in marker ---
Write-Output "--- Mitigation opt-in marker ---"
$markerPath = "HKLM:\SOFTWARE\Fleet\YellowKey"
$markerName = "AllowMitigation"
$marker     = (Get-ItemProperty -Path $markerPath -Name $markerName -ErrorAction SilentlyContinue).$markerName
$markerStr  = if ($null -eq $marker) { "(not set)" } else { $marker.ToString() }
Write-State "AllowMitigation" $markerStr

Write-Output ""
Write-Output "Done. No changes made."
exit 0
