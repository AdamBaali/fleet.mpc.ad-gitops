<#
.SYNOPSIS
    Migrates a Windows host to Secure Boot CA 2023 trust chain (KB5025885).

.DESCRIPTION
    Closes the PCA-2011-trusted boot manager attack surface:
      - CVE-2023-24932 (BlackLotus) bootkit swap
      - CVE-2025-48804 (BitUnlocker) downgrade attack on TPM-only BitLocker
    Both attacks rely on PCA 2011 staying trusted in the firmware DB. The
    DBX revocation step (part of AvailableUpdates = 0x5944) closes both.

    Also ensures continued Secure Boot servicing past PCA 2011 expiry
    (October 2026). Does NOT mitigate YellowKey (CVE-2026-45585, WinRE
    autofstx bypass) -- run mitigate-windows-yellowkey.ps1 for that.

    Verifies completion by checking BOTH:
      - File signatures on disk (bootmgfw.efi, winload.efi, winresume.efi)
      - Registry servicing state machine (UEFICA2023Status, Error, Capable)

    Idempotent and conservative:
      - Skips if all 3 boot binaries are already signed by CA 2023
      - Respects in-progress workflows (does not retrigger)
      - Bails if errored state detected (does not retry blindly)
      - Bails if prerequisites missing (Secure Boot off, CU too old)
      - Bails if boot file inspection is incomplete (missing or unreadable)

.OUTPUTS
    Structured key:value output to stdout for log capture / parsing.

.NOTES
    Exit codes:
      0 = Migration complete, in progress, or just triggered (no action needed)
      2 = Secure Boot not enabled in firmware, or check failed (BIOS/legacy/error)
      3 = Cumulative update too old, or Secure-Boot-Update task failed to start
      4 = Errored state (UEFICA2023Error != 0); manual investigation required
      5 = Reboot pending; reboot to advance migration
      6 = Boot file missing or signature unreadable; remediation skipped

    References:
      KB5025885: https://support.microsoft.com/en-us/topic/41a975df-beb2-40c1-99a3-b3ff139f832d
      MS Secure Boot Playbook (Feb 2026):
      https://techcommunity.microsoft.com/blog/windows-itpro-blog/secure-boot-playbook-for-certificates-expiring-in-2026/4469235
#>

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== Windows Secure Boot CA 2023 migration ==="
Write-Output ""

# --- Preflight: Secure Boot enabled ---
$secureBootEnabled = $false
try {
    $secureBootEnabled = Confirm-SecureBootUEFI
} catch {
    Write-Output "FAIL: Secure Boot check failed: $($_.Exception.Message)"
    Write-Output "      Host may be BIOS/legacy or not a UEFI system. No firmware toggle to flip."
    exit 2
}
if (-not $secureBootEnabled) {
    Write-Output "FAIL: Secure Boot not enabled in firmware. Enable before running."
    exit 2
}
Write-State "Secure Boot" "enabled"

# --- Preflight: cumulative update current enough ---
$taskPath = "\Microsoft\Windows\PI\"
$taskName = "Secure-Boot-Update"
$secBootTask = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $secBootTask) {
    Write-Output "FAIL: ${taskPath}${taskName} task missing."
    Write-Output "      Cumulative update too old. Install latest CU and retry."
    exit 3
}
Write-State "Secure-Boot-Update task" "present"

# --- Inspect file signatures (single pass) ---
Write-Output ""
Write-Output "--- File signatures ---"

$bootFiles = @(
    "$env:SystemRoot\Boot\EFI\bootmgfw.efi",
    "$env:SystemRoot\System32\winload.efi",
    "$env:SystemRoot\System32\winresume.efi"
)

$migratedCount   = 0
$missingCount    = 0
$unreadableCount = 0
foreach ($f in $bootFiles) {
    $name = Split-Path $f -Leaf
    if (-not (Test-Path $f)) {
        Write-State $name "MISSING"
        $missingCount++
        continue
    }
    $issuer = $null
    try {
        $issuer = (Get-AuthenticodeSignature $f).SignerCertificate.Issuer
    } catch {
        Write-State $name "signature read failed: $($_.Exception.Message)"
        $unreadableCount++
        continue
    }
    if (-not $issuer) {
        Write-State $name "signature unreadable (no signer certificate)"
        $unreadableCount++
    } elseif ($issuer -match 'Windows UEFI CA 2023') {
        Write-State $name "CA 2023 (migrated)"
        $migratedCount++
    } elseif ($issuer -match 'Production PCA 2011') {
        Write-State $name "PCA 2011 (not migrated)"
    } else {
        Write-State $name "unknown issuer: $issuer"
    }
}

# --- Bail if inspection incomplete ---
if ($missingCount -gt 0) {
    Write-Output ""
    Write-Output "FAIL: $missingCount boot file(s) missing. Not triggering migration."
    Write-State "State" "inspection_incomplete_missing_files"
    exit 6
}
if ($unreadableCount -gt 0) {
    Write-Output ""
    Write-Output "FAIL: $unreadableCount boot file(s) have unreadable signatures. Not triggering migration."
    Write-State "State" "inspection_incomplete_unreadable_signatures"
    exit 6
}

# --- Inspect registry servicing state machine ---
Write-Output ""
Write-Output "--- Registry servicing state ---"

$servicing  = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
$secureboot = "HKLM:\SYSTEM\CurrentControlSet\Control\Secureboot"

$regStatus    = (Get-ItemProperty -Path $servicing  -Name "UEFICA2023Status"         -ErrorAction SilentlyContinue).UEFICA2023Status
$regCapable   = (Get-ItemProperty -Path $servicing  -Name "WindowsUEFICA2023Capable" -ErrorAction SilentlyContinue).WindowsUEFICA2023Capable
$regError     = (Get-ItemProperty -Path $servicing  -Name "UEFICA2023Error"          -ErrorAction SilentlyContinue).UEFICA2023Error
$regAvailable = (Get-ItemProperty -Path $secureboot -Name "AvailableUpdates"         -ErrorAction SilentlyContinue).AvailableUpdates

$statusStr    = if ($null -ne $regStatus)    { $regStatus.ToString() }                            else { "(not set)" }
$capableStr   = if ($null -ne $regCapable)   { $regCapable.ToString() }                           else { "(not set)" }
$errorStr     = if ($null -ne $regError)     { $regError.ToString() }                             else { "(not set)" }
$availableStr = if ($null -ne $regAvailable) { "0x{0:X4} ({1})" -f $regAvailable, $regAvailable } else { "(not set)" }

Write-State "UEFICA2023Status"         $statusStr
Write-State "WindowsUEFICA2023Capable" $capableStr
Write-State "UEFICA2023Error"          $errorStr
Write-State "AvailableUpdates"         $availableStr

# --- Decision: idempotency, conservative paths ---
Write-Output ""
Write-Output "--- Decision ---"

# Fully migrated: all 3 files on CA 2023, no error
if ($migratedCount -eq 3 -and ($null -eq $regError -or $regError -eq 0)) {
    Write-Output "OK: Fully migrated. All boot binaries signed by CA 2023."
    exit 0
}

# Errored state: do not retry
if ($null -ne $regError -and $regError -ne 0) {
    Write-Output "FAIL: UEFICA2023Error = $regError. Manual investigation required."
    Write-Output "      Check Event Viewer > System for:"
    Write-Output "        1036 = PCA 2023 added to DB (success)"
    Write-Output "        1037 = PCA 2011 added to DBX (success)"
    Write-Output "        1795 = generic DB/DBX update event (see KB5016061)"
    Write-Output "        1799 = boot manager signed by CA 2023 applied (success)"
    Write-Output "        1801 = DB update blocked"
    Write-Output "        1803 = no PK-signed KEK"
    exit 4
}

# Firmware servicing reports Updated -- done at firmware level even if OS-side files lag
if ($regStatus -eq 'Updated') {
    Write-Output "OK: Servicing reports Updated (capable = $regCapable)."
    Write-Output "    Firmware-level migration complete. OS-side files may show PCA 2011"
    Write-Output "    until the next Windows Update cycle refreshes the staging copy."
    Write-Output "    Run verify-windows-ca-2023.ps1 to confirm firmware DB / ESP state."
    exit 0
}

# In-flight: leave alone
if ($regStatus -eq 'InProgress') {
    Write-Output "OK: Migration in progress (UEFICA2023Status = InProgress)."
    Write-Output "    Files migrated: $migratedCount / 3. Reboot may be required to advance."
    exit 0
}

# Reboot pending
if ($regAvailable -eq 0x4100) {
    Write-Output "WAIT: Reboot pending (AvailableUpdates = 0x4100)."
    Write-Output "      Reboot to advance migration. Re-run script after reboot."
    exit 5
}

# --- Trigger full deployment ---
if ($migratedCount -gt 0) {
    Write-Output "Partial migration detected ($migratedCount / 3 files on CA 2023). Retriggering."
} else {
    Write-Output "Triggering CA 2023 migration (AvailableUpdates = 0x5944) ..."
}

Set-ItemProperty -Path $secureboot -Name "AvailableUpdates" -Value 0x5944 -Type DWord -Force

try {
    Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName
} catch {
    Write-Output "FAIL: Could not start ${taskPath}${taskName} task: $($_.Exception.Message)"
    Write-Output "      AvailableUpdates is set, but task did not start."
    Write-Output "      Host is in partial state. Check Task Scheduler permissions and re-run."
    exit 3
}

Write-Output "OK: Migration triggered. Reboot required (sometimes two)."
Write-Output "    Re-run this script after each reboot to confirm progress."
exit 0
