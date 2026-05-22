<#
.SYNOPSIS
    Inspects YellowKey exposure and mitigation state on a Windows host.
    Read-only.

.DESCRIPTION
    Reports the per-host signals the windows-yellowkey report cannot
    surface via native osquery tables alone:
      - WinRE enabled state (from `reagentc /info`)
      - BitLocker key protector types per volume (TPM-only vs TPM+PIN
        vs Recovery, etc.) -- Get-BitLockerVolume, not osquery
      - Fleet YellowKey AllowMitigation and BootExecMitigated markers

    READ-ONLY. Does not mount winre.wim and does not change WinRE state.
    For ground truth on the offline WinRE image's BootExecute value,
    re-run mitigate-windows-yellowkey.ps1: it is idempotent and reports
    the current BootExecute contents before deciding whether to act.

.NOTES
    Intended use:
      - Confirm hosts flagged by the windows-yellowkey report
      - Decide which hosts get the AllowMitigation marker set
      - Sanity-check before running mitigate

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
               elseif ($os -match 'Windows 11' -or $os -match 'Server 2022' -or $os -match 'Server 2025') { 'in_scope (check WinRE and markers below)' }
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

# --- Fleet YellowKey markers ---
Write-Output "--- Fleet YellowKey markers ---"
$ykPath = 'HKLM:\SOFTWARE\Fleet\YellowKey'

$allow = (Get-ItemProperty -Path $ykPath -Name 'AllowMitigation'   -ErrorAction SilentlyContinue).AllowMitigation
$boot  = (Get-ItemProperty -Path $ykPath -Name 'BootExecMitigated' -ErrorAction SilentlyContinue).BootExecMitigated

$allowStr = if ($null -eq $allow) { '(not set)' } else { $allow.ToString() }
$bootStr  = if ($null -eq $boot)  { '(not set)' } else { $boot.ToString() }
Write-State "AllowMitigation"      $allowStr
Write-State "BootExecMitigated"    $bootStr

Write-Output ""
Write-Output "Notes:"
Write-Output "  AllowMitigation = 1  -> mitigate-windows-yellowkey.ps1 may strip autofstx"
Write-Output "  BootExecMitigated = 1 -> mitigate ran successfully on this host"
Write-Output "  WinRE Disabled         -> a heavier mitigation is already in place"

Write-Output ""
Write-Output "Done. No changes made."
exit 0
