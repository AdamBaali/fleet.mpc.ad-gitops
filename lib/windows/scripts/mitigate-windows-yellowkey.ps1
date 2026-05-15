<#
.SYNOPSIS
    Disables Windows Recovery Environment (WinRE) to mitigate the YellowKey
    BitLocker bypass.

.DESCRIPTION
    YellowKey (May 2026, no CVE) abuses NTFS transaction log replay in WinRE
    to read a BitLocker-protected volume without authentication. Affects
    Windows 11 and Server 2022/2025. Windows 10 is not affected. No patch
    as of May 2026. TPM + PIN does NOT protect (researcher-confirmed).

    The only known mitigation is removing WinRE via `reagentc /disable`.

    DESTRUCTIVE. Disabling WinRE removes:
      - Push-button reset (Settings > Recovery > Reset this PC)
      - The in-place BitLocker recovery flow that runs in WinRE
      - System Restore from boot
      - Recovery Drive image restore

    Gated by an explicit per-host registry marker that the admin must set
    before the script will take action:

      HKLM\SOFTWARE\Fleet\YellowKey\AllowMitigation = 1 (DWORD)

    Set this only on hosts where WinRE removal is acceptable. Idempotent:
    skips if WinRE is already disabled. Reverse with
    unmitigate-windows-yellowkey.ps1.

.OUTPUTS
    Structured key:value output to stdout for log capture.

.NOTES
    Exit codes:
      0 = WinRE disabled (action taken or already disabled)
      2 = Opt-in marker missing; no action taken
      3 = OS not affected (Windows 10 etc.); no action taken
      4 = reagentc returned a non-zero exit code or post-state check failed
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== Windows YellowKey mitigation (disable WinRE) ==="
Write-Output ""

# --- Opt-in marker ---
# Refuse to act without an explicit per-host opt-in. reagentc /disable
# is hard to recover at scale if applied to the wrong hosts.
$markerPath = "HKLM:\SOFTWARE\Fleet\YellowKey"
$markerName = "AllowMitigation"
$marker     = (Get-ItemProperty -Path $markerPath -Name $markerName -ErrorAction SilentlyContinue).$markerName

if ($null -eq $marker -or $marker -ne 1) {
    Write-Output "SKIP: Opt-in marker not set."
    Write-Output "      Set $markerPath\$markerName = 1 (DWORD) to allow mitigation."
    Write-Output "      Refusing to disable WinRE without explicit opt-in."
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
    Write-Output "      Windows 10 ships without the vulnerable WinRE component."
    Write-State "State" "skipped_os_not_affected"
    exit 3
}

# --- Current WinRE state ---
$infoText = (& reagentc /info 2>&1) | Out-String
if ($infoText -match 'Windows RE status:\s*Disabled') {
    Write-Output "OK: WinRE already disabled. No action needed."
    Write-State "State" "already_disabled"
    exit 0
}

# --- Disable WinRE ---
Write-Output ""
Write-Output "Disabling WinRE ..."

$disableOutput = & reagentc /disable 2>&1
$disableExit   = $LASTEXITCODE
Write-Output (($disableOutput | Out-String).Trim())

if ($disableExit -ne 0) {
    Write-Output ""
    Write-Output "FAIL: reagentc /disable exited with code $disableExit."
    Write-State "State" "reagentc_error"
    exit 4
}

# --- Confirm ---
$infoText = (& reagentc /info 2>&1) | Out-String
if ($infoText -match 'Windows RE status:\s*Disabled') {
    Write-Output "OK: WinRE disabled."
    Write-State "State" "disabled"
    exit 0
}

Write-Output "FAIL: reagentc reports WinRE still enabled after /disable."
Write-State "State" "still_enabled_after_disable"
exit 4
