<#
.SYNOPSIS
    Reverses mitigate-windows-yellowkey.ps1 by restoring autofstx.exe to
    the WinRE image's Session Manager BootExecute value.

.DESCRIPTION
    Use when:
      - A patch ships for YellowKey (CVE-2026-45585) and the autofstx
        strip is no longer needed.
      - A host is being decommissioned from the mitigated label and
        WinRE should return to its factory configuration.
      - You need WinRE's FsTx auto-recovery utility back for a known
        recovery scenario.

    Idempotent. Skips if autofstx is already present in BootExecute.

    No opt-in marker required. Returning a host to its default WinRE
    configuration is the safe direction relative to the mitigation.

    Clears the Fleet post-mitigation marker on success:
      HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated

.OUTPUTS
    Structured key:value output to stdout.

.NOTES
    Exit codes:
      0 = autofstx restored, or already present
      3 = WinRE disabled; cannot edit the offline image
      4 = WinRE mount/edit/unmount failed; manual investigation needed
      5 = autofstx still absent after commit
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== Windows YellowKey unmitigate (restore autofstx) ==="
Write-Output ""

# --- Current WinRE state ---
$info     = (& reagentc /info 2>&1) | Out-String
$reState  = if ($info -match 'Windows RE status:\s*(Enabled|Disabled)') { $Matches[1] } else { 'unknown' }
$winreLoc = if ($info -match 'Windows RE location:\s*(\S.*)')           { $Matches[1].Trim() } else { '' }
Write-State "WinRE status"   $reState
Write-State "WinRE location" $(if ($winreLoc) { $winreLoc } else { '(none reported)' })

if ($reState -eq 'Disabled') {
    Write-Output "SKIP: WinRE disabled. Run reagentc /enable first if you want to edit the image."
    Write-State "State" "skipped_winre_disabled"
    exit 3
}
if ($reState -ne 'Enabled' -or -not $winreLoc) {
    Write-Output "FAIL: WinRE state or location is not usable."
    Write-State "State" "winre_state_not_usable"
    exit 4
}

# --- Plan the mount ---
$mountDir  = Join-Path $env:ProgramData 'Fleet\state\yk-winre-mount'
$hiveAlias = 'YK_SYSTEM_RESTORE'
$wimPath   = Join-Path $winreLoc 'winre.wim'

if (-not (Test-Path $mountDir)) {
    New-Item -Path $mountDir -ItemType Directory -Force | Out-Null
}

Write-Output ""
Write-Output "Disabling WinRE to release winre.wim ..."
& reagentc /disable | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-State "State" "reagentc_disable_failed"
    exit 4
}

$addedAutofstx = $false
$bootexecAfter = $null
$mounted       = $false
$hiveLoaded    = $false

try {
    # --- Mount WIM ---
    Write-Output "Mounting WinRE image ..."
    & dism /mount-image /imagefile:"$wimPath" /index:1 /mountdir:"$mountDir" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-State "State" "dism_mount_failed"
        throw "DISM mount failed"
    }
    $mounted = $true

    # --- Load offline SYSTEM hive ---
    $offlineHive = Join-Path $mountDir 'Windows\System32\config\SYSTEM'
    & reg load "HKLM\$hiveAlias" "$offlineHive" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-State "State" "reg_load_failed"
        throw "reg load failed"
    }
    $hiveLoaded = $true

    # --- Restore autofstx to BootExecute ---
    $sessKey = "HKLM:\$hiveAlias\ControlSet001\Control\Session Manager"
    $cur = @((Get-ItemProperty -Path $sessKey -Name BootExecute -ErrorAction Stop).BootExecute)
    Write-Output ""
    Write-Output "BootExecute (before): $($cur -join ' | ')"

    if ($cur | Where-Object { $_ -like 'autofstx*' }) {
        Write-Output "autofstx already present. Nothing to restore."
        $bootexecAfter = $cur -join ' | '
    } else {
        # Microsoft's default value on Win11/Server2022/2025 WinRE images.
        # The stock entry is the bare command 'autofstx'.
        $new = @($cur + 'autofstx')
        Set-ItemProperty -Path $sessKey -Name BootExecute -Value $new -Type MultiString
        Write-Output "BootExecute (after):  $($new -join ' | ')"
        $bootexecAfter = $new -join ' | '
        $addedAutofstx = $true
    }
}
catch {
    Write-Output "FAIL: $($_.Exception.Message)"
}
finally {
    if ($hiveLoaded) {
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 500
        & reg unload "HKLM\$hiveAlias" | Out-Null
    }
    if ($mounted) {
        $commit = if ($addedAutofstx) { '/commit' } else { '/discard' }
        Write-Output ""
        Write-Output "Unmounting WinRE image ($commit) ..."
        & dism /unmount-image /mountdir:"$mountDir" $commit | Out-Null
    }
    Write-Output "Re-enabling WinRE ..."
    & reagentc /enable | Out-Null
}

if (-not $mounted) { exit 4 }
if ($null -eq $bootexecAfter) {
    Write-State "State" "edit_failed"
    exit 4
}
if ($bootexecAfter -notmatch 'autofstx') {
    Write-State "State" "autofstx_still_absent_after_commit"
    exit 5
}

# Clear the post-mitigation marker.
try {
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Fleet\YellowKey' -Name 'BootExecMitigated' -ErrorAction SilentlyContinue
} catch {
    Write-Output "WARN: could not clear BootExecMitigated marker: $($_.Exception.Message)"
}

if ($addedAutofstx) {
    Write-State "State" "autofstx_restored"
} else {
    Write-State "State" "autofstx_already_present"
}
exit 0
