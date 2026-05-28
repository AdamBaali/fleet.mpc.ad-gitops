<#
.SYNOPSIS
    Installs and loads the windows_yellowkey osquery extension on this host.

.DESCRIPTION
    Idempotent installer for the windows_yellowkey osquery extension under
    fleetd on Windows. Designed to run as the run_script remediation on the
    windows-yellowkey-extension policy.

    Flow:
      1. Pre-flight: Orbit installed, Fleet osquery service present.
      2. Pick the URL and SHA-256 for this host's architecture.
      3. Ensure the extensions directory exists, harden its ACL.
      4. Download the binary to a temp path, verify SHA-256, move into place.
      5. Harden the binary ACL.
      6. Add the binary path to extensions.load (idempotent), harden that file.
      7. Restart the Fleet osquery service so osquery autoloads the extension.

    The script does not push osqueryd flags. fleetd regenerates osquery.flags
    from agent options on every config refresh, so the extensions flags must
    live in agent options, not in osquery.flags. Add this override to the
    team's agent_options (see fleets/workstations.yml in this repo):

        agent_options:
          command_line_flags:
            disable_extensions: false
            extensions_autoload: 'C:\Program Files\Orbit\extensions.load'
            extensions_timeout: 10
            extensions_interval: 3

    These are osqueryd command-line flags, not config options. Fleet requires
    command_line_flags at the top level of agent_options ("command_line_flags"
    should be part of the top level object) and rejects them under
    overrides.platforms.<platform>, so they apply to every platform on the
    team. On macOS and Linux hosts the Windows autoload path does not exist;
    osquery logs one warning then continues.

.OUTPUTS
    Structured key:value output to stdout for log capture.

.NOTES
    Exit codes:
      0 = Installed; service back to Running, extension will load on next start
      2 = Orbit not present
      3 = Fleet osquery service not present
      4 = Filesystem operation failed (directory, move, loader write, ACL)
      5 = Service did not return to Running after restart
      6 = Download failed
      7 = Downloaded file failed SHA-256 verification
      8 = Unsupported architecture

    Update workflow:
      1. Rebuild with `make build` and commit the new binaries.
      2. Bump $ExtensionVersion and both $Builds entries' Sha values.
      3. Open a PR. After merge, failing hosts pull the new binary on the
         next policy run.

    References:
      Fleet guide: https://fleetdm.com/guides/deploying-custom-osquery-extensions-in-fleet-a-step-by-step-guide
      Extension source: extensions/windows_yellowkey/ in this repo.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# Extension identity. Bump these when the committed binaries change.
# ============================================================================
$ExtensionName    = 'windows_yellowkey'
$ExtensionVersion = '1.0.0'
$BaseUrl          = 'https://raw.githubusercontent.com/AdamBaali/fleet.mpc.ad-gitops/main/extensions/windows_yellowkey'

$Builds = @{
    'AMD64' = @{
        Asset = 'windows_yellowkey-amd64.exe'
        Sha   = '19A820F3B2975CB88C525FF19ED77F4001FAD1F5DA51F112762E29D649513B35'
    }
    'ARM64' = @{
        Asset = 'windows_yellowkey-arm64.exe'
        Sha   = 'B9B984140825FC1B9E856072AAC89CD6A7E1E76E08CD036EE7834E2A9E872AA0'
    }
}
# ============================================================================

$OrbitRoot     = 'C:\Program Files\Orbit'
$ExtensionsDir = Join-Path $OrbitRoot 'extensions'
$ExtensionPath = Join-Path $ExtensionsDir "$ExtensionName.ext.exe"
$LoaderPath    = Join-Path $OrbitRoot 'extensions.load'
$ServiceName   = 'Fleet osquery'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

function Set-HardenedAcl {
    # Reset $Path to: owner Administrators, no inherited ACEs, full control for
    # SYSTEM and Administrators, read+execute for Users. Re-asserted on every
    # run so a drifted host (Group Policy churn, manual edits) self-heals.
    # Well-known SIDs are used instead of names so this works on non-English
    # Windows.
    param([string]$Path, [bool]$IsDirectory)

    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $adminsSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $usersSid  = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')

    $acl = Get-Acl -Path $Path
    # Disable inheritance, drop inherited ACEs (false = do not preserve).
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($r in @($acl.Access)) { [void]$acl.RemoveAccessRule($r) }
    $acl.SetOwner($adminsSid)

    $inherit = if ($IsDirectory) {
        [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    } else {
        [System.Security.AccessControl.InheritanceFlags]::None
    }
    $rules = @(
        [System.Security.AccessControl.FileSystemAccessRule]::new(
            $systemSid, 'FullControl', $inherit, 'None', 'Allow'),
        [System.Security.AccessControl.FileSystemAccessRule]::new(
            $adminsSid, 'FullControl', $inherit, 'None', 'Allow'),
        [System.Security.AccessControl.FileSystemAccessRule]::new(
            $usersSid, 'ReadAndExecute', $inherit, 'None', 'Allow')
    )
    foreach ($r in $rules) { $acl.AddAccessRule($r) }
    Set-Acl -Path $Path -AclObject $acl
}

Write-Output "=== windows_yellowkey extension installer ==="
Write-Output ""

# --- Pre-flight ---
if (-not (Test-Path $OrbitRoot)) {
    Write-Output "FAIL: Orbit not installed at $OrbitRoot."
    Write-State 'State' 'orbit_missing'
    exit 2
}
if ($null -eq (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    Write-Output "FAIL: service '$ServiceName' not found. Is fleetd installed?"
    Write-State 'State' 'service_missing'
    exit 3
}

# --- Architecture selection ---
$arch = $env:PROCESSOR_ARCHITECTURE
if (-not $Builds.ContainsKey($arch)) {
    Write-Output "FAIL: unsupported architecture: $arch"
    Write-State 'State' 'unsupported_arch'
    exit 8
}
$asset       = $Builds[$arch].Asset
$expectedSha = $Builds[$arch].Sha.ToUpper()
$url         = "$BaseUrl/$asset"
Write-State 'Architecture' $arch
Write-State 'Asset'        $asset
Write-State 'Target'       $ExtensionPath
Write-State 'Download URL' $url

# --- Extensions directory ---
if (-not (Test-Path $ExtensionsDir)) {
    try {
        New-Item -ItemType Directory -Path $ExtensionsDir -Force | Out-Null
    } catch {
        Write-Output "FAIL: could not create ${ExtensionsDir}: $($_.Exception.Message)"
        Write-State 'State' 'extensions_dir_unwritable'
        exit 4
    }
}
try {
    Set-HardenedAcl -Path $ExtensionsDir -IsDirectory $true
} catch {
    Write-Output "FAIL: could not harden ACL on ${ExtensionsDir}: $($_.Exception.Message)"
    Write-State 'State' 'acl_failed_dir'
    exit 4
}

# --- Download with SHA-256 verification ---
$tempPath = Join-Path $env:TEMP "$ExtensionName-$([guid]::NewGuid()).download"
try {
    Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing -TimeoutSec 120
} catch {
    Write-Output "FAIL: download failed: $($_.Exception.Message)"
    Write-Output "      Confirm $url is reachable from the host."
    Write-State 'State' 'download_failed'
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 6
}
$actualSha = (Get-FileHash -Path $tempPath -Algorithm SHA256).Hash.ToUpper()
if ($actualSha -ne $expectedSha) {
    Write-Output "FAIL: SHA-256 mismatch. expected=$expectedSha actual=$actualSha"
    Write-State 'State' 'checksum_mismatch'
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 7
}
Write-State 'SHA-256' "ok ($actualSha)"

try {
    Move-Item -Path $tempPath -Destination $ExtensionPath -Force
} catch {
    Write-Output "FAIL: could not move to ${ExtensionPath}: $($_.Exception.Message)"
    Write-State 'State' 'move_failed'
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 4
}
Write-State 'Placed' $ExtensionPath

try {
    Set-HardenedAcl -Path $ExtensionPath -IsDirectory $false
} catch {
    Write-Output "FAIL: could not harden ACL on ${ExtensionPath}: $($_.Exception.Message)"
    Write-State 'State' 'acl_failed_binary'
    exit 4
}

# --- extensions.load: add our path if missing, write ASCII (no BOM) ---
$existing = @()
if (Test-Path $LoaderPath) {
    $existing = @(Get-Content -Path $LoaderPath -ErrorAction SilentlyContinue |
                  Where-Object { $_ -and $_.Trim() -ne '' })
}
if ($existing -notcontains $ExtensionPath) {
    $existing += $ExtensionPath
    try {
        # ASCII no-BOM: a UTF-16 or UTF-8-BOM file makes osquery skip the loader
        # and silently load zero extensions.
        [System.IO.File]::WriteAllLines($LoaderPath, $existing, [System.Text.ASCIIEncoding]::new())
    } catch {
        Write-Output "FAIL: could not write ${LoaderPath}: $($_.Exception.Message)"
        Write-State 'State' 'loader_write_failed'
        exit 4
    }
    Write-State 'extensions.load' 'updated'
} else {
    Write-State 'extensions.load' 'already lists the binary'
}
try {
    Set-HardenedAcl -Path $LoaderPath -IsDirectory $false
} catch {
    Write-Output "FAIL: could not harden ACL on ${LoaderPath}: $($_.Exception.Message)"
    Write-State 'State' 'acl_failed_loader'
    exit 4
}

# --- Restart Fleet osquery so it picks up the new extension ---
try {
    Restart-Service -Name $ServiceName -Force
} catch {
    Write-Output "FAIL: could not restart ${ServiceName}: $($_.Exception.Message)"
    Write-State 'State' 'restart_failed'
    exit 5
}
Start-Sleep -Seconds 5

$svc = Get-Service -Name $ServiceName
if ($svc.Status -ne 'Running') {
    Write-Output "FAIL: $ServiceName did not return to Running after restart (status: $($svc.Status))."
    Write-State 'State' 'service_not_running'
    exit 5
}

Write-Output ""
Write-Output "OK: installed $ExtensionName v$ExtensionVersion at $ExtensionPath."
Write-Output "    Verify in Fleet (live query):"
Write-Output "      SELECT 1 FROM osquery_registry"
Write-Output "        WHERE registry = 'table' AND name = 'windows_yellowkey' AND active = 1;"
Write-Output "      SELECT state FROM windows_yellowkey;"
Write-State 'State' 'installed'
exit 0
