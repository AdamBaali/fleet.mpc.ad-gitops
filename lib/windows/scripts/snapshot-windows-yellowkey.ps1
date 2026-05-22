<#
.SYNOPSIS
    Writes Windows YellowKey exposure state to a snapshot file.

.DESCRIPTION
    Captures signals osquery cannot reach natively:
      - WinRE enabled state and image location (reagentc /info)
      - BitLocker key protector types per volume
        (Get-BitLockerVolume; bitlocker_info in osquery has no
        key-protector column)
      - Fleet YellowKey opt-in marker
      - Fleet YellowKey BootExecMitigated marker, set by
        mitigate-windows-yellowkey.ps1 after a successful autofstx strip

    Writes key=value lines to:
      C:\ProgramData\Fleet\state\windows-yellowkey-snapshot.txt

    The windows-yellowkey report LEFT JOINs this file via osquery's
    file_lines table and pivots key=value into columns. Without the
    snapshot the report still surfaces today's OS + BitLocker rows;
    the WinRE column reads NULL and the verdict falls back to
    `affected_if_winre_on`.

    Does NOT mount winre.wim. The BootExecMitigated marker is written
    by mitigate-windows-yellowkey.ps1 on success and read here. For
    ground truth on the WinRE image contents, re-run mitigate (it is
    idempotent and reports the current BootExecute state).

    Silent on success.

.NOTES
    Run on whatever cadence suits the environment. Policy run_script
    is intentionally not used (3-retry cap kills daily refresh, and
    the policy slot belongs to the real mitigation script when one
    is wired up).

    Exit codes:
      0 = Snapshot written
      1 = State directory unwritable
#>

$ErrorActionPreference = 'Stop'

$stateDir  = 'C:\ProgramData\Fleet\state'
$statePath = Join-Path $stateDir 'windows-yellowkey-snapshot.txt'

$lines = New-Object System.Collections.Generic.List[string]

function Add-Snap {
    param([string]$Key, [object]$Value)
    if ($null -eq $Value) { $Value = 'unknown' }
    $sanitized = ($Value.ToString()) -replace '[\r\n]+', ' '
    $lines.Add(('{0}={1}' -f $Key, $sanitized))
}

# --- OS ---
try {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    Add-Snap 'os_caption' $os
} catch {
    Add-Snap 'os_error' $_.Exception.Message
}

# --- WinRE ---
try {
    $infoText = (& reagentc /info 2>&1) | Out-String
    $reState  = if ($infoText -match 'Windows RE status:\s*(Enabled|Disabled)') { $Matches[1] } else { 'unknown' }
    $reLoc    = if ($infoText -match 'Windows RE location:\s*(\S.*)')           { $Matches[1].Trim() } else { '' }
    Add-Snap 'winre_enabled' ($reState -eq 'Enabled')
    Add-Snap 'winre_state'   $reState
    if (-not [string]::IsNullOrEmpty($reLoc)) {
        Add-Snap 'winre_location' $reLoc
    }
} catch {
    Add-Snap 'winre_error' $_.Exception.Message
}

# --- BitLocker volumes ---
# Get-BitLockerVolume surfaces KeyProtector types that bitlocker_info
# in osquery cannot. Aggregate across volumes so the snapshot is
# column-friendly: one comma-separated list of types per host.
try {
    $volumes = Get-BitLockerVolume -ErrorAction Stop
    if ($null -eq $volumes -or $volumes.Count -eq 0) {
        Add-Snap 'volumes_count' 0
        Add-Snap 'key_protectors' '(none)'
    } else {
        Add-Snap 'volumes_count' $volumes.Count
        $protectedCount = @($volumes | Where-Object { $_.ProtectionStatus -eq 'On' }).Count
        Add-Snap 'volumes_protected_count' $protectedCount

        $allTypes = @()
        foreach ($v in $volumes) {
            $types = @($v.KeyProtector | ForEach-Object { $_.KeyProtectorType.ToString() })
            $allTypes += $types
        }
        $unique = ($allTypes | Sort-Object -Unique) -join ','
        if ([string]::IsNullOrEmpty($unique)) { $unique = '(none)' }
        Add-Snap 'key_protectors' $unique

        # TPM-only is the YellowKey-relevant case for the published PoC.
        # TPM+PIN blocks the public PoC but not the researcher's withheld
        # variant, so we surface the count for both audit and customer comms.
        $tpmOnly = @($volumes | Where-Object {
            $kp = @($_.KeyProtector | ForEach-Object { $_.KeyProtectorType.ToString() })
            ($kp -contains 'Tpm') -and (-not ($kp -contains 'TpmPin')) -and (-not ($kp -contains 'TpmPinStartupKey'))
        }).Count
        Add-Snap 'volumes_tpm_only_count' $tpmOnly
    }
} catch {
    Add-Snap 'bitlocker_error' $_.Exception.Message
}

# --- Fleet YellowKey markers ---
$ykPath = 'HKLM:\SOFTWARE\Fleet\YellowKey'

$marker = (Get-ItemProperty -Path $ykPath -Name 'AllowMitigation' -ErrorAction SilentlyContinue).AllowMitigation
if ($null -eq $marker) {
    Add-Snap 'allow_mitigation_marker' 'not_set'
} else {
    Add-Snap 'allow_mitigation_marker' $marker
}

$bootExec = (Get-ItemProperty -Path $ykPath -Name 'BootExecMitigated' -ErrorAction SilentlyContinue).BootExecMitigated
Add-Snap 'bootexec_mitigated' ($bootExec -eq 1)

Add-Snap 'snapshot_generated' (Get-Date -Format 'o')

# --- Write to disk ---
try {
    if (-not (Test-Path $stateDir)) {
        New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
    }
    Set-Content -Path $statePath -Value $lines -Encoding ASCII -Force
} catch {
    Write-Error "Snapshot write failed: $($_.Exception.Message)"
    exit 1
}

exit 0
