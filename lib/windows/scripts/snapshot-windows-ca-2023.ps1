<#
.SYNOPSIS
    Writes Windows Secure Boot CA 2023 firmware state to a snapshot file.

.DESCRIPTION
    Captures signals osquery cannot reach natively:
      - Firmware DB allow list (Windows UEFI CA 2023,
        Microsoft UEFI CA 2023, Production PCA 2011)
      - Firmware KEK (KEK 2K CA 2023, KEK CA 2011)
      - DBX deny list size and PCA 2011 revocation presence
      - ESP boot manager issuer (the real one firmware loads)
      - Secure Boot enabled state
      - ISO 8601 UTC timestamp of capture, used by the report's
        freshness gate

    Writes key=value lines to:
      C:\ProgramData\Fleet\state\windows-ca-2023-snapshot.txt

    The windows-ca-2023 report LEFT JOINs this file via osquery's
    file_lines table. The report computes age in hours and treats
    data older than 48 hours as stale (verdicts fall back to the
    native-only set). Re-run this script to refresh.

    Silent on success. Errors print to stderr; the snapshot file is
    still written with the best-effort signals it could gather.

.NOTES
    Run on whatever cadence suits the environment:
      - Fleet > Scripts > Run against a label (manual cadence)
      - Host-side scheduled task wrapping this script
      - Side effect of an admin running verify-windows-ca-2023.ps1
        (verify does not call this automatically)

    Policy run_script auto-remediation is NOT a good fit: Fleet caps
    at 3 retries per policy failure, so a daily refresh need cannot
    be served by a staleness policy. Keep the policy slot open for
    the actual compliance remediation (migrate-windows-ca-2023.ps1).

    Exit codes:
      0 = Snapshot written
      1 = State directory unwritable
#>

$ErrorActionPreference = 'Stop'

$stateDir  = 'C:\ProgramData\Fleet\state'
$statePath = Join-Path $stateDir 'windows-ca-2023-snapshot.txt'

$lines = New-Object System.Collections.Generic.List[string]

function Add-Snap {
    param([string]$Key, [object]$Value)
    if ($null -eq $Value) { $Value = 'unknown' }
    $sanitized = ($Value.ToString()) -replace '[\r\n]+', ' '
    $lines.Add(('{0}={1}' -f $Key, $sanitized))
}

# --- Secure Boot enabled ---
try {
    $sb = Confirm-SecureBootUEFI
    Add-Snap 'secure_boot_enabled' $sb
} catch {
    Add-Snap 'secure_boot_enabled' 'unknown'
    Add-Snap 'secure_boot_error'   $_.Exception.Message
}

# --- Firmware DB (allow list) ---
# Decode as Latin-1 (codepage 28591): 1:1 byte mapping, no lossy substitution
# of high bytes. ASCII would replace bytes >= 128 with '?', which can split
# CN literals at DER length-prefix bytes.
try {
    $dbBytes = (Get-SecureBootUEFI db).bytes
    $dbText  = [Text.Encoding]::GetEncoding(28591).GetString($dbBytes)
    Add-Snap 'firmware_db_has_ca_2023'           ($dbText -match 'Windows UEFI CA 2023')
    Add-Snap 'firmware_db_has_msft_uefi_ca_2023' ($dbText -match 'Microsoft UEFI CA 2023')
    Add-Snap 'firmware_db_has_pca_2011'          ($dbText -match 'Microsoft Windows Production PCA 2011')
    Add-Snap 'firmware_db_size'                  $dbBytes.Length
} catch {
    Add-Snap 'firmware_db_error' $_.Exception.Message
}

# --- Firmware KEK ---
try {
    $kekBytes = (Get-SecureBootUEFI KEK).bytes
    $kekText  = [Text.Encoding]::GetEncoding(28591).GetString($kekBytes)
    Add-Snap 'firmware_kek_has_2k_ca_2023' ($kekText -match 'Microsoft Corporation KEK 2K CA 2023')
    Add-Snap 'firmware_kek_has_ca_2011'    ($kekText -match 'Microsoft Corporation KEK CA 2011')
} catch {
    Add-Snap 'firmware_kek_error' $_.Exception.Message
}

# --- DBX (deny list) ---
try {
    $dbxBytes = (Get-SecureBootUEFI dbx).bytes
    $dbxText  = [Text.Encoding]::GetEncoding(28591).GetString($dbxBytes)
    Add-Snap 'dbx_revokes_pca_2011' ($dbxText -match 'Microsoft Windows Production PCA 2011')
    Add-Snap 'dbx_size'             $dbxBytes.Length
} catch {
    Add-Snap 'dbx_error' $_.Exception.Message
}

# --- ESP boot manager ---
# Mount the EFI System Partition as S: long enough to read the boot
# manager signature, then dismount. Only firmware loads from here;
# C:\Windows\Boot\EFI\bootmgfw.efi is a staging copy.
$mountLetter = 'S'
$mounted     = $false
try {
    mountvol "${mountLetter}:" /s 2>&1 | Out-Null
    $mounted = ($LASTEXITCODE -eq 0)
    $espPath = "${mountLetter}:\EFI\Microsoft\Boot\bootmgfw.efi"
    if (Test-Path $espPath) {
        $espSig    = Get-AuthenticodeSignature $espPath
        $espIssuer = $espSig.SignerCertificate.Issuer
        $tag = if ([string]::IsNullOrEmpty($espIssuer))     { 'unreadable' }
               elseif ($espIssuer -match 'Windows UEFI CA 2023') { 'ca_2023' }
               elseif ($espIssuer -match 'Production PCA 2011')  { 'pca_2011' }
               else { 'unknown' }
        Add-Snap 'esp_bootmgr_issuer'     $tag
        Add-Snap 'esp_bootmgr_sig_status' $espSig.Status
    } else {
        Add-Snap 'esp_bootmgr_issuer' 'missing'
    }
} catch {
    Add-Snap 'esp_error' $_.Exception.Message
} finally {
    if ($mounted) { mountvol "${mountLetter}:" /d 2>&1 | Out-Null }
}

# --- Freshness timestamp (UTC, SQLite-parseable, culture-invariant) ---
# Pass InvariantCulture so non-Latin digit locales (fa-IR, ar-SA, th-TH)
# emit Latin digits. Drop the trailing 'Z' because SQLite < 3.42 does not
# recognise the Z modifier and would return NULL.
$nowUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss',
            [System.Globalization.CultureInfo]::InvariantCulture)
Add-Snap 'snapshot_generated' $nowUtc

# --- Write to disk ---
try {
    if (-not (Test-Path $stateDir)) {
        New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
    }
    # ASCII so PowerShell 5 does not add a UTF-8 BOM (osquery's
    # file_lines sees the BOM as line content otherwise).
    Set-Content -Path $statePath -Value $lines -Encoding ASCII -Force
} catch {
    Write-Error "Snapshot write failed: $($_.Exception.Message)"
    exit 1
}

exit 0
