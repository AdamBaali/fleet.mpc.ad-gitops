<#
.SYNOPSIS
    Re-enables Windows Recovery Environment (WinRE). Reverses
    mitigate-windows-yellowkey.ps1.

.DESCRIPTION
    Use when:
      - A host moves out of high-sensitivity scope
      - A host needs WinRE for an imminent recovery or reset
      - A patch ships for YellowKey and recovery flows should come back

    Idempotent. Skips if WinRE is already enabled. No opt-in marker
    required: restoring recovery is the safe direction.

.OUTPUTS
    Structured key:value output to stdout.

.NOTES
    Exit codes:
      0 = WinRE enabled (action taken or already enabled)
      4 = reagentc returned a non-zero exit code or post-state check failed
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== Windows YellowKey unmitigate (re-enable WinRE) ==="
Write-Output ""

# --- Current state ---
$infoText = (& reagentc /info 2>&1) | Out-String
if ($infoText -match 'Windows RE status:\s*Enabled') {
    Write-Output "OK: WinRE already enabled. No action needed."
    Write-State "State" "already_enabled"
    exit 0
}

# --- Enable WinRE ---
Write-Output "Enabling WinRE ..."

$enableOutput = & reagentc /enable 2>&1
$enableExit   = $LASTEXITCODE
Write-Output (($enableOutput | Out-String).Trim())

if ($enableExit -ne 0) {
    Write-Output ""
    Write-Output "FAIL: reagentc /enable exited with code $enableExit."
    Write-State "State" "reagentc_error"
    exit 4
}

# --- Confirm ---
$infoText = (& reagentc /info 2>&1) | Out-String
if ($infoText -match 'Windows RE status:\s*Enabled') {
    Write-Output "OK: WinRE enabled."
    Write-State "State" "enabled"
    exit 0
}

Write-Output "FAIL: reagentc reports WinRE still disabled after /enable."
Write-State "State" "still_disabled_after_enable"
exit 4
