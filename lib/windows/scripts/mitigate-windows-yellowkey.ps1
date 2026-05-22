<#
.SYNOPSIS
    Mitigates the YellowKey BitLocker bypass (CVE-2026-45585) by removing
    autofstx.exe from the WinRE image's Session Manager BootExecute value.

.DESCRIPTION
    YellowKey (CVE-2026-45585, CVSS 6.8, disclosed May 12 2026) abuses
    autofstx.exe inside WinRE. autofstx replays NTFS transaction logs from
    any attached volume's System Volume Information\FsTx folder, deletes
    winpeshl.ini, and drops the attacker into cmd.exe with the BitLocker
    volume already unlocked. Affects Windows 11, Server 2022, Server 2025.
    Windows 10 is not affected.

    Adapted from Microsoft's reference script in the CVE-2026-45585 MSRC
    advisory FAQ ("Is there a script that I can copy and paste to implement
    a mitigation?"). Microsoft's flow:
      1. Mount WinRE via `reagentc /mountre /path`
      2. Load the offline SYSTEM hive
      3. Walk active ControlSets via \Select\Current and \Select\Default
      4. Strip autofstx.exe from BootExecute in each ControlSet
      5. Unload hive, unmount with /commit
      6. reagentc /disable + /enable to re-seal the BitLocker measurement chain

    Fleet additions on top of Microsoft's flow:
      - Gated by HKLM\SOFTWARE\Fleet\YellowKey\AllowMitigation = 1
      - Writes HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated = 1 on success
        so the snapshot script can surface mitigated_bootexec_stripped without
        re-mounting the WIM
      - Skips silently if WinRE is already disabled (stronger mitigation in place)
      - Granular exit codes for Fleet reporting
      - Structured key:value output for log capture

    One-way. There is no unmitigate counterpart. If a patch ships, the patch
    supersedes the strip; if a host needs autofstx back for some other reason,
    restore manually and clear HKLM\SOFTWARE\Fleet\YellowKey\BootExecMitigated.

    TPM + PIN blocks the published PoC but not the researcher's withheld
    variant. Treat TPM + PIN as raising attacker cost, not as a substitute
    for this mitigation.

.PARAMETER MountPath
    Directory to use as the WinRE mount point. Created if missing.
    Default: C:\ProgramData\Fleet\state\yk-winre-mount

.OUTPUTS
    Structured key:value output to stdout for log capture.

.NOTES
    Exit codes:
      0 = autofstx removed, already absent, or WinRE already disabled
      2 = AllowMitigation marker missing; no action taken
      3 = OS not affected (Windows 10 etc.); no action taken
      4 = Mount, edit, unmount, or re-seal failed; manual investigation needed

    References:
      MSRC CVE-2026-45585 (FAQ section contains the canonical Microsoft script):
        https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-45585
      Eclypsium technical analysis:
        https://eclypsium.com/blog/yellowkey-bitlocker-bypass-windows-recovery-environment/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$MountPath = (Join-Path $env:ProgramData 'Fleet\state\yk-winre-mount')
)

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== Windows YellowKey mitigation (autofstx strip) ==="
Write-Output ""

$EntryToRemove = 'autofstx.exe'
$HiveName      = 'YK_WinREHive'

$hiveLoaded   = $false
$imageMounted = $false
$mountCreated = $false
$changesMade  = $false

# --- Fleet: opt-in marker ---
# Editing the WinRE image is a deliberate, label-scoped action. Refuse
# without explicit consent so a misconfigured policy cannot mass-edit
# recovery images.
$markerPath = 'HKLM:\SOFTWARE\Fleet\YellowKey'
$marker     = (Get-ItemProperty -Path $markerPath -Name 'AllowMitigation' -ErrorAction SilentlyContinue).AllowMitigation
if ($null -eq $marker -or $marker -ne 1) {
    Write-Output "SKIP: Opt-in marker not set."
    Write-Output "      Set $markerPath\AllowMitigation = 1 (DWORD) to allow mitigation."
    Write-State "State" "skipped_no_optin"
    exit 2
}
Write-State "Opt-in marker" "present"

# --- Fleet: OS check ---
$os = (Get-CimInstance Win32_OperatingSystem).Caption
Write-State "OS" $os
$affected = ($os -match 'Windows 11' -or $os -match 'Server 2022' -or $os -match 'Server 2025')
if (-not $affected) {
    Write-Output "SKIP: $os is not in YellowKey's affected OS list."
    Write-State "State" "skipped_os_not_affected"
    exit 3
}

# --- Admin check (Microsoft reference) ---
try {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output "FAIL: must run as Administrator."
        Write-State "State" "not_admin"
        exit 4
    }
} catch {
    Write-Output "FAIL: admin check error: $($_.Exception.Message)"
    Write-State "State" "admin_check_failed"
    exit 4
}

# --- WinRE state (language-agnostic, Microsoft reference) ---
$winreOutput = & reagentc /info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Output "FAIL: reagentc /info exit $LASTEXITCODE"
    Write-State "State" "reagentc_info_failed"
    exit 4
}
$winreText = $winreOutput -join "`n"

if ($winreText -match "[:：]\s*Disabled\b") {
    Write-Output "OK: WinRE disabled. Stronger mitigation already in place; nothing to do."
    Write-State "State" "winre_already_disabled"
    exit 0
}
if ($winreText -notmatch "[:：]\s*Enabled\b") {
    Write-Output "FAIL: could not parse reagentc /info output."
    Write-State "State" "winre_state_unknown"
    exit 4
}
Write-State "WinRE status" "Enabled"

# --- Mount WinRE (Microsoft reference) ---
try {
    if (-not (Test-Path $MountPath)) {
        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
        $mountCreated = $true
    } else {
        $existing = Get-ChildItem -Path $MountPath -Force -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Output "FAIL: $MountPath not empty. Clean it or pass -MountPath."
            Write-State "State" "mount_dir_dirty"
            exit 4
        }
    }

    $mountOutput = & reagentc /mountre /path $MountPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Output "FAIL: reagentc /mountre: $mountOutput"
        Write-State "State" "mount_failed"
        exit 4
    }
    $imageMounted = $true
    Write-State "Mounted at" $MountPath
} catch {
    Write-Output "FAIL: mount error: $($_.Exception.Message)"
    Write-State "State" "mount_error"
    exit 4
}

# --- Load offline SYSTEM hive (Microsoft reference) ---
try {
    $hivePath = $null
    foreach ($candidate in @(
        "$MountPath\Windows\System32\config\SYSTEM",
        "$MountPath\windows\system32\config\SYSTEM"
    )) {
        if (Test-Path $candidate) { $hivePath = $candidate; break }
    }
    if (-not $hivePath) {
        $found = Get-ChildItem -Path $MountPath -Recurse -Filter 'SYSTEM' -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -match 'config\\SYSTEM$' } | Select-Object -First 1
        if ($found) { $hivePath = $found.FullName }
    }
    if (-not $hivePath) {
        Write-Output "FAIL: SYSTEM hive not found in mounted image."
        Write-State "State" "hive_not_found"
        & reagentc /unmountre /path $MountPath /discard 2>&1 | Out-Null
        $imageMounted = $false
        exit 4
    }

    & reg load "HKLM\$HiveName" $hivePath 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "FAIL: reg load exit $LASTEXITCODE"
        Write-State "State" "reg_load_failed"
        & reagentc /unmountre /path $MountPath /discard 2>&1 | Out-Null
        $imageMounted = $false
        exit 4
    }
    $hiveLoaded = $true
    Write-State "Hive loaded" "HKLM\$HiveName"
} catch {
    Write-Output "FAIL: hive load error: $($_.Exception.Message)"
    Write-State "State" "hive_load_error"
    if ($imageMounted) {
        & reagentc /unmountre /path $MountPath /discard 2>&1 | Out-Null
        $imageMounted = $false
    }
    exit 4
}

# --- Walk active ControlSets and strip autofstx.exe (Microsoft reference) ---
try {
    $selectPath  = "Registry::HKEY_LOCAL_MACHINE\$HiveName\Select"
    $selectProps = Get-ItemProperty -Path $selectPath -ErrorAction SilentlyContinue

    if ($selectProps -and $selectProps.Current) {
        $csNumbers = @($selectProps.Current)
        if ($selectProps.Default -and $selectProps.Default -ne $selectProps.Current) {
            $csNumbers += $selectProps.Default
        }
        $controlSets = $csNumbers | ForEach-Object { 'ControlSet{0:D3}' -f [int]$_ }
    } else {
        $controlSets = @('ControlSet001')
    }
    Write-State "Active ControlSets" ($controlSets -join ', ')

    foreach ($cs in $controlSets) {
        $regPath = "Registry::HKEY_LOCAL_MACHINE\$HiveName\$cs\Control\Session Manager"
        $cur = (Get-ItemProperty -Path $regPath -Name 'BootExecute' -ErrorAction SilentlyContinue).BootExecute
        if (-not $cur) { continue }

        $new = @($cur | Where-Object {
            $_ -and
            ($_ -ne $EntryToRemove) -and
            ($_ -notmatch "^\s*$([regex]::Escape($EntryToRemove))\s*$")
        })

        if ($new.Count -eq @($cur).Count) {
            Write-State "$cs" "autofstx absent"
            continue
        }

        Set-ItemProperty -Path $regPath -Name 'BootExecute' -Value $new -Type MultiString
        $changesMade = $true
        Write-State "$cs" "stripped autofstx"
    }
} catch {
    Write-Output "FAIL: edit error: $($_.Exception.Message)"
    Write-State "State" "edit_error"
    # Fall through to cleanup below.
}

# --- Unload hive (Microsoft retry pattern) ---
[gc]::Collect()
Start-Sleep -Seconds 2
& reg unload "HKLM\$HiveName" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    [gc]::Collect()
    Start-Sleep -Seconds 3
    & reg unload "HKLM\$HiveName" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "FAIL: reg unload would not release hive. Close any Registry Editor windows and retry."
        Write-State "State" "reg_unload_failed"
        & reagentc /unmountre /path $MountPath /discard 2>&1 | Out-Null
        exit 4
    }
}
$hiveLoaded = $false

# --- Unmount: commit on changes, discard on no-op ---
$flag = if ($changesMade) { '/commit' } else { '/discard' }
& reagentc /unmountre /path $MountPath $flag 2>&1 | Out-Null
$unmountExit = $LASTEXITCODE
$imageMounted = $false
if ($unmountExit -ne 0) {
    Write-Output "FAIL: reagentc /unmountre $flag exit $unmountExit"
    Write-State "State" "unmount_failed"
    exit 4
}
Write-State "Unmount" $flag

# --- Re-seal BitLocker measurement chain (Microsoft reference) ---
# Only needed when the WIM changed. The disable + enable cycle
# refreshes WinRE's registration so the BitLocker trust chain stays intact.
if ($changesMade) {
    & reagentc /disable 2>&1 | Out-Null
    & reagentc /enable 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "FAIL: reagentc /enable after re-seal failed (exit $LASTEXITCODE)."
        Write-Output "      WinRE may need manual recovery: run reagentc /enable."
        Write-State "State" "reseal_failed"
        exit 4
    }
    Write-State "WinRE re-sealed" "disable + enable"
}

# --- Cleanup mount directory if we created it ---
if ($mountCreated -and (Test-Path $MountPath)) {
    Remove-Item -Path $MountPath -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Fleet: success marker ---
try {
    if (-not (Test-Path $markerPath)) {
        New-Item -Path $markerPath -Force | Out-Null
    }
    Set-ItemProperty -Path $markerPath -Name 'BootExecMitigated' -Value 1 -Type DWord -Force
} catch {
    Write-Output "WARN: could not write BootExecMitigated marker: $($_.Exception.Message)"
}

if ($changesMade) {
    Write-State "State" "bootexec_stripped"
} else {
    Write-State "State" "bootexec_already_stripped"
}
exit 0
