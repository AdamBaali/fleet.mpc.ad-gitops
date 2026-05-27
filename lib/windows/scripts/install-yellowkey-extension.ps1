<#
.SYNOPSIS
    Installs and loads the windows_yellowkey osquery extension on this host.

.DESCRIPTION
    Implements the deployment flow from Fleet's "Deploying custom osquery
    extensions" guide:
      1. Download the architecture-matching binary (amd64 or arm64) from the repo.
      2. Place it under %ProgramFiles%\Orbit\extensions\ as a .ext.exe.
      3. Register the path in %ProgramFiles%\Orbit\extensions.load
         (one path per line, the osquery --extensions_autoload format).
      4. Restart the orbit service so osquery loads the extension.

    Download + placement + registration are skipped when already done.
    The orbit restart runs every time the script is invoked, because the
    policy only triggers this script when the extension is NOT loaded, so
    a re-run means the previous load did not take.

    Attached as the run_script remediation for the
    windows-yellowkey-extension policy, which passes only when the
    windows_yellowkey table is queryable.

.PARAMETER BaseUrl
    Base URL the architecture-matching binary is fetched from. Default: the
    prebuilt binaries committed under extensions/windows_yellowkey/ on the
    repo's main branch (raw.githubusercontent.com). No release or tag needed.
    Override to point at an internal mirror or a private-repo raw URL + token.

.PARAMETER ExtensionsDir
    Directory for the extension binary. Default: %ProgramFiles%\Orbit\extensions.

.PARAMETER AutoloadFile
    osquery extensions autoload file. Default: %ProgramFiles%\Orbit\extensions.load.

.OUTPUTS
    Structured key:value output to stdout for log capture.

.NOTES
    Exit codes:
      0 = Installed, registered, and orbit restarted
      2 = Unsupported architecture
      3 = Download failed
      4 = File placement or autoload registration failed
      5 = Downloaded file is not a PE32+
      6 = Placed and registered, but orbit restart was not possible
          (extension loads on the next orbit restart)

    References:
      Fleet guide: https://fleetdm.com/guides/deploying-custom-osquery-extensions-in-fleet-a-step-by-step-guide
      Extension source: extensions/windows_yellowkey/ in this repo.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = 'https://raw.githubusercontent.com/AdamBaali/fleet.mpc.ad-gitops/main/extensions/windows_yellowkey',

    [Parameter(Mandatory = $false)]
    [string]$ExtensionsDir = (Join-Path $env:ProgramFiles 'Orbit\extensions'),

    [Parameter(Mandatory = $false)]
    [string]$AutoloadFile = (Join-Path $env:ProgramFiles 'Orbit\extensions.load')
)

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== windows_yellowkey extension installer ==="
Write-Output ""

# osquery on Windows expects extension binaries to end in .ext.exe.
$installedName = 'windows_yellowkey.ext.exe'
$targetPath    = Join-Path $ExtensionsDir $installedName

# --- Detect architecture ---
$arch = $env:PROCESSOR_ARCHITECTURE
$asset = switch ($arch) {
    'AMD64' { 'windows_yellowkey-amd64.exe' }
    'ARM64' { 'windows_yellowkey-arm64.exe' }
    default { $null }
}
if (-not $asset) {
    Write-Output "FAIL: unsupported architecture: $arch"
    Write-State 'State' 'unsupported_arch'
    exit 2
}
Write-State 'Architecture' $arch
Write-State 'Asset'        $asset
Write-State 'Target'       $targetPath

# --- Ensure extensions directory ---
if (-not (Test-Path $ExtensionsDir)) {
    try {
        New-Item -Path $ExtensionsDir -ItemType Directory -Force | Out-Null
    } catch {
        Write-Output "FAIL: could not create $ExtensionsDir : $($_.Exception.Message)"
        Write-State 'State' 'extensions_dir_unwritable'
        exit 4
    }
}

# --- Download + verify + place (skip if a good binary is already there) ---
$alreadyPlaced = (Test-Path $targetPath) -and ((Get-Item $targetPath).Length -gt 1000000)
if ($alreadyPlaced) {
    Write-State 'Binary' 'already present'
} else {
    $url      = "$BaseUrl/$asset"
    $tempPath = Join-Path $env:TEMP "$asset.download"
    Write-State 'Download URL' $url

    # Download with curl.exe, which ships with every YellowKey-affected SKU
    # (Windows 10 1803+, Server 2019+). -f fails on HTTP errors like 404,
    # -L follows GitHub's redirect, -s silences the progress meter, -S keeps
    # real error text, --retry rides out transient resets. Invoke-WebRequest
    # is flaky on the GitHub redirect and reports "connection closed".
    #
    # curl writes to stderr; with ErrorActionPreference = Stop and 2>&1 that
    # becomes a terminating NativeCommandError before we can read the exit
    # code, so drop to Continue for the call and check $LASTEXITCODE instead.
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (-not (Test-Path $curl)) { $curl = 'curl.exe' }

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $curlOut = & $curl -fsSL --retry 3 --retry-connrefused --connect-timeout 20 --max-time 300 -o $tempPath $url 2>&1
    $curlExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($curlExit -ne 0) {
        Write-Output "FAIL: download failed (curl exit $curlExit): $(($curlOut | Out-String).Trim())"
        if ($curlExit -eq 22) {
            Write-Output "      HTTP error. Confirm the binary exists at the URL:"
            Write-Output "        $url"
            Write-Output "      It should be committed under extensions/windows_yellowkey/ on the"
            Write-Output "      branch this URL points at. If the repo is private, the host needs"
            Write-Output "      an authenticated URL (pass -BaseUrl with a token)."
        }
        Write-State 'State' 'download_failed'
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        exit 3
    }
    if (-not (Test-Path $tempPath)) {
        Write-Output "FAIL: curl reported success but $tempPath is missing."
        Write-State 'State' 'download_missing'
        exit 3
    }

    # Verify PE32+ magic bytes (MZ at offset 0).
    try {
        $fs = [System.IO.File]::OpenRead($tempPath)
        $hdr = New-Object byte[] 2
        $null = $fs.Read($hdr, 0, 2)
        $fs.Close()
    } catch {
        Write-Output "FAIL: could not read downloaded file header: $($_.Exception.Message)"
        Write-State 'State' 'header_read_failed'
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        exit 5
    }
    if ($hdr[0] -ne 0x4D -or $hdr[1] -ne 0x5A) {
        Write-Output "FAIL: downloaded file is not a Windows PE (no MZ header)."
        Write-State 'State' 'not_a_pe'
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        exit 5
    }

    try {
        Move-Item -Path $tempPath -Destination $targetPath -Force
    } catch {
        Write-Output "FAIL: could not move to $targetPath : $($_.Exception.Message)"
        Write-State 'State' 'move_failed'
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        exit 4
    }
    Write-State 'Placed' $targetPath
}

# --- Register the path in extensions.load ---
try {
    $lines = @()
    if (Test-Path $AutoloadFile) {
        $lines = @(Get-Content -Path $AutoloadFile -ErrorAction SilentlyContinue |
                   Where-Object { $_ -and $_.Trim() -ne '' })
    }
    if ($lines -notcontains $targetPath) {
        $lines += $targetPath
        Set-Content -Path $AutoloadFile -Value $lines -Encoding ASCII -Force
        Write-State 'extensions.load' 'updated'
    } else {
        Write-State 'extensions.load' 'already listed'
    }
} catch {
    Write-Output "FAIL: could not update $AutoloadFile : $($_.Exception.Message)"
    Write-State 'State' 'autoload_write_failed'
    exit 4
}

# --- Restart orbit so osquery reloads with the extension ---
# Runs on every invocation: the policy only calls this script when the
# extension is not loaded, so reaching here means the load needs (re)applying.
$svc = $null
foreach ($name in @('Fleet osquery', 'Orbit', 'fleetd')) {
    if (Get-Service -Name $name -ErrorAction SilentlyContinue) { $svc = $name; break }
}
if (-not $svc) {
    Write-Output "WARN: orbit service not found by known names (Fleet osquery / Orbit / fleetd)."
    Write-Output "      Binary placed and registered; osquery loads it on the next orbit restart."
    Write-State 'State' 'placed_restart_deferred'
    exit 6
}
try {
    Restart-Service -Name $svc -Force
    Write-State 'Restarted service' $svc
} catch {
    Write-Output "WARN: could not restart '$svc': $($_.Exception.Message)"
    Write-Output "      Binary placed and registered; restart orbit to load."
    Write-State 'State' 'placed_restart_failed'
    exit 6
}

Write-Output ""
Write-Output "OK: binary placed, path written to extensions.load, orbit restarted."
Write-Output "    orbit autoloads $AutoloadFile on restart and hands osquery"
Write-Output "    --extensions_autoload for it, so the table registers with no"
Write-Output "    agent-options flag."
Write-Output "    Verify:      SELECT state FROM windows_yellowkey;"
Write-Output "    Local check: orbit.exe shell -- --extension `"$targetPath`" --allow-unsafe"
Write-State 'State' 'installed'
exit 0
