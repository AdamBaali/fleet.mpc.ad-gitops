<#
.SYNOPSIS
    Mitigates the YellowKey BitLocker bypass (CVE-2026-45585) by removing
    autofstx.exe from the WinRE image's Session Manager BootExecute value.

.DESCRIPTION
    YellowKey (CVE-2026-45585, CVSS 6.8, disclosed May 12 2026) abuses
    autofstx.exe inside WinRE. autofstx replays NTFS transaction logs from
    any attached volume's System Volume Information\FsTx folder, which lets
    an attacker delete winpeshl.ini and drop into cmd.exe with the
    BitLocker volume unlocked. Affects Windows 11, Server 2022, Server 2025.
    Windows 10 is not affected.

    Microsoft's official mitigation (published May 19 2026, scripted May 21)
    removes the autofstx.exe entry from WinRE's
    HKLM\SYSTEM\ControlSet001\Control\Session Manager\BootExecute so the
    vulnerable replay never runs. Less destructive than disabling WinRE:
    push-button reset, the in-WinRE BitLocker recovery flow, System Restore
    from boot, and Recovery Drive restore all keep working.

    TPM + PIN blocks the published PoC but not the researcher's withheld
    variant. Treat TPM + PIN as raising attacker cost, not as a substitute
    for this mitigation.

    Gated by an explicit per-host marker that an admin must set before this
    script will mount the WinRE image:

      HKLM\SOFTWARE\Fleet\YellowKey\AllowMitigation = 1 (DWORD)

    Use set-yellowkey-allow-mitigation.ps1 to set the marker against a
    label-targeted subset.

    Idempotent. Skips if autofstx is already absent or if WinRE is already
    disabled (a stronger mitigation already in place).

    Writes a post-mitigation marker on success so the snapshot script and
    report can surface the state without re-mounting the WIM:

      HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1 (DWORD)

.OUTPUTS
    Structured key:value output to stdout for log capture.

.NOTES
    Exit codes:
      0 = autofstx removed, or already absent, or WinRE already disabled
      2 = AllowMitigation marker missing; no action taken
      3 = OS not affected (Windows 10 etc.); no action taken
      4 = WinRE mount/edit/unmount failed; manual investigation needed
      5 = autofstx still present after commit; mitigation did not stick

    References:
      MSRC CVE-2026-45585:
        https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585
      Eclypsium technical analysis:
        https://eclypsium.com/blog/yellowkey-bitlocker-bypass-windows-recovery-environment/
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== Windows YellowKey mitigation (autofstx strip) ==="
Write-Output ""

# --- Opt-in marker ---
# Editing the WinRE image is a deliberate, label-scoped action. Refuse
# without explicit consent so a misconfigured policy cannot mass-edit
# recovery images.
$markerPath = 'HKLM:\SOFTWARE\Fleet\YellowKey'
$markerName = 'AllowMitigation'
$marker     = (Get-ItemProperty -Path $markerPath -Name $markerName -ErrorAction SilentlyContinue).$markerName

if ($null -eq $marker -or $marker -ne 1) {
    Write-Output "SKIP: Opt-in marker not set."
    Write-Output "      Set $markerPath\$markerName = 1 (DWORD) to allow mitigation."
    Write-State "State" "skipped_no_optin"
    exit 2
}
Write-State "Opt-in marker" "present"

# --- OS check ---
$os = (Get-CimInstance Win32_OperatingSystem).Caption
Write-State "OS" $os

$affected = ($os -match 'Windows 11' -or $os -match 'Server 2022' -or $os -match 'Server 2025')
if (-not $affected) {
    Write-Output "SKIP: $os is not in YellowKey's affected OS list."
    Write-State "State" "skipped_os_not_affected"
    exit 3
}

# --- Current WinRE state ---
$info     = (& reagentc /info 2>&1) | Out-String
$reState  = if ($info -match 'Windows RE status:\s*(Enabled|Disabled)') { $Matches[1] } else { 'unknown' }
$winreLoc = if ($info -match 'Windows RE location:\s*(\S.*)')           { $Matches[1].Trim() } else { '' }
Write-State "WinRE status"   $reState
Write-State "WinRE location" $(if ($winreLoc) { $winreLoc } else { '(none reported)' })

# A host with WinRE off is already mitigated, with stronger coverage than
# this script provides. Do not re-enable just to strip autofstx.
if ($reState -eq 'Disabled') {
    Write-Output "OK: WinRE disabled. Stronger mitigation already in place; nothing to do."
    Write-State "State" "winre_already_disabled"
    exit 0
}
if ($reState -ne 'Enabled') {
    Write-Output "FAIL: reagentc /info did not report a clear Enabled/Disabled state."
    Write-State "State" "winre_state_unknown"
    exit 4
}
if (-not $winreLoc) {
    Write-Output "FAIL: WinRE enabled but no location reported. Cannot locate winre.wim."
    Write-State "State" "winre_location_missing"
    exit 4
}

# --- Plan the mount ---
# reagentc /disable releases winre.wim for offline editing via DISM.
# We re-enable at the end so push-button reset and the WinRE recovery
# flow keep working.
$mountDir  = Join-Path $env:ProgramData 'Fleet\state\yk-winre-mount'
$hiveAlias = 'YK_SYSTEM'
$wimPath   = Join-Path $winreLoc 'winre.wim'

Write-State "WIM path"       $wimPath
Write-State "Mount directory" $mountDir

if (-not (Test-Path $mountDir)) {
    New-Item -Path $mountDir -ItemType Directory -Force | Out-Null
}

# --- Release winre.wim ---
Write-Output ""
Write-Output "Disabling WinRE to release winre.wim ..."
$disableOut  = & reagentc /disable 2>&1
$disableExit = $LASTEXITCODE
Write-Output (($disableOut | Out-String).Trim())
if ($disableExit -ne 0) {
    Write-State "State" "reagentc_disable_failed"
    exit 4
}

$strippedCount = 0
$bootexecAfter = $null
$mounted       = $false
$hiveLoaded    = $false

try {
    # --- Mount WIM ---
    Write-Output ""
    Write-Output "Mounting WinRE image ..."
    $mountOut  = & dism /mount-image /imagefile:"$wimPath" /index:1 /mountdir:"$mountDir" 2>&1
    $mountExit = $LASTEXITCODE
    if ($mountExit -ne 0) {
        Write-Output (($mountOut | Out-String).Trim())
        Write-State "State" "dism_mount_failed"
        throw "DISM mount failed (exit $mountExit)"
    }
    $mounted = $true

    # --- Load offline SYSTEM hive ---
    $offlineHive = Join-Path $mountDir 'Windows\System32\config\SYSTEM'
    if (-not (Test-Path $offlineHive)) {
        Write-State "State" "offline_hive_missing"
        throw "Offline SYSTEM hive missing at $offlineHive"
    }
    & reg load "HKLM\$hiveAlias" "$offlineHive" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-State "State" "reg_load_failed"
        throw "reg load failed (exit $LASTEXITCODE)"
    }
    $hiveLoaded = $true

    # --- Strip autofstx from BootExecute ---
    $sessKey = "HKLM:\$hiveAlias\ControlSet001\Control\Session Manager"
    $cur = @((Get-ItemProperty -Path $sessKey -Name BootExecute -ErrorAction Stop).BootExecute)
    Write-Output ""
    Write-Output "BootExecute (before): $($cur -join ' | ')"

    $new = @($cur | Where-Object { $_ -notlike 'autofstx*' })
    $strippedCount = $cur.Count - $new.Count

    if ($strippedCount -gt 0) {
        Set-ItemProperty -Path $sessKey -Name BootExecute -Value $new -Type MultiString
        Write-Output "BootExecute (after):  $($new -join ' | ')"
        Write-Output "Stripped $strippedCount entr$(if ($strippedCount -eq 1) { 'y' } else { 'ies' })."
    } else {
        Write-Output "BootExecute already lacks autofstx. Nothing to remove."
    }
    $bootexecAfter = $new -join ' | '
}
catch {
    Write-Output "FAIL: $($_.Exception.Message)"
}
finally {
    if ($hiveLoaded) {
        # Force GC so PowerShell drops handles on the loaded hive before unload.
        # reg unload fails silently if any process still has a handle.
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 500
        & reg unload "HKLM\$hiveAlias" | Out-Null
    }
    if ($mounted) {
        $commit = if ($strippedCount -gt 0) { '/commit' } else { '/discard' }
        Write-Output ""
        Write-Output "Unmounting WinRE image ($commit) ..."
        & dism /unmount-image /mountdir:"$mountDir" $commit | Out-Null
    }
    Write-Output "Re-enabling WinRE ..."
    & reagentc /enable | Out-Null
}

# --- Verify ---
# Bail if we failed mid-flow. The catch ate the exception so flow continued
# into finally, which is what we want for cleanup; signal the failure here.
if (-not $mounted) {
    exit 4
}

if ($null -eq $bootexecAfter) {
    Write-State "State" "edit_failed"
    exit 4
}

if ($bootexecAfter -match 'autofstx') {
    Write-State "State" "autofstx_still_present_after_commit"
    exit 5
}

# --- Write the post-mitigation marker ---
# Snapshot script reads this so the report can surface
# `mitigated_bootexec_stripped` without re-mounting the WIM each run.
try {
    if (-not (Test-Path $markerPath)) {
        New-Item -Path $markerPath -Force | Out-Null
    }
    Set-ItemProperty -Path $markerPath -Name 'BootExecMitigated' -Value 1 -Type DWord -Force
} catch {
    Write-Output "WARN: could not write BootExecMitigated marker: $($_.Exception.Message)"
}

if ($strippedCount -gt 0) {
    Write-State "State" "bootexec_stripped"
} else {
    Write-State "State" "bootexec_already_stripped"
}
exit 0
