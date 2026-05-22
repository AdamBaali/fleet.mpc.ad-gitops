<#
.SYNOPSIS
    Installs the windows_yellowkey osquery extension binary on this host.

.DESCRIPTION
    Detects host architecture (amd64 / arm64), downloads the matching
    binary from a GitHub release, verifies it's a valid PE32+ executable,
    and places it at C:\Program Files\Fleet\Extensions\.

    Idempotent. Exits 0 if the binary is already present at the target
    path with a reasonable size.

    Loading the extension into orbit is a separate concern. After this
    script completes, either:
      - Test interactively:
          'C:\Program Files\Orbit\bin\orbit\orbit.exe' shell -- `
              --extension <path> --allow-unsafe
      - Configure orbit's extensions.load file to autoload on service start.

    Designed to be attached to the windows-yellowkey-extension Fleet
    policy as a run_script remediation. The policy passes once the
    binary is at the target path; failing hosts trigger this script.

.PARAMETER ReleaseBaseUrl
    Base URL where the binaries are hosted. Default points at the
    latest GitHub release of this repo. Override to test against a
    custom URL (e.g., a draft release or internal mirror).

.PARAMETER InstallPath
    Directory where the binary lands. Default: %ProgramFiles%\Fleet\Extensions.

.OUTPUTS
    Structured key:value output to stdout for log capture.

.NOTES
    Exit codes:
      0 = Binary installed, or already present at the target path
      2 = Unsupported architecture
      3 = Download failed
      4 = Install directory unwritable, or move-into-place failed
      5 = Downloaded file is not a PE32+ (corrupted, wrong content, etc.)

    References:
      Extension source: lib/windows/extensions/yellowkey/ in this repo.
      Allen Houchins' pattern:
        https://github.com/allenhouchins/fleet-extensions/tree/main/secureboot_cert_update
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReleaseBaseUrl = 'https://github.com/AdamBaali/fleet.mpc.ad-gitops/releases/latest/download',

    [Parameter(Mandatory = $false)]
    [string]$InstallPath = (Join-Path $env:ProgramFiles 'Fleet\Extensions')
)

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

Write-Output "=== windows_yellowkey extension installer ==="
Write-Output ""

# --- Detect architecture ---
$arch = $env:PROCESSOR_ARCHITECTURE
$binaryName = switch ($arch) {
    'AMD64' { 'windows_yellowkey-amd64.exe' }
    'ARM64' { 'windows_yellowkey-arm64.exe' }
    default { $null }
}
if (-not $binaryName) {
    Write-Output "FAIL: unsupported architecture: $arch"
    Write-State 'State' 'unsupported_arch'
    exit 2
}
Write-State 'Architecture' $arch
Write-State 'Binary'       $binaryName

$targetPath = Join-Path $InstallPath $binaryName
Write-State 'Target path' $targetPath

# --- Idempotency: skip if already installed ---
if (Test-Path $targetPath) {
    $existingSize = (Get-Item $targetPath).Length
    # Real binaries are several MB. Anything under 1 MB is suspect.
    if ($existingSize -gt 1000000) {
        Write-Output "OK: already installed at $targetPath ($existingSize bytes)."
        Write-State 'State' 'already_installed'
        exit 0
    }
    Write-Output "Existing file looks too small ($existingSize bytes); replacing."
}

# --- Ensure install directory exists ---
if (-not (Test-Path $InstallPath)) {
    try {
        New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
        Write-State 'Created' $InstallPath
    } catch {
        Write-Output "FAIL: could not create $InstallPath : $($_.Exception.Message)"
        Write-State 'State' 'install_path_unwritable'
        exit 4
    }
}

# --- Download to a temp path ---
$downloadUrl = "$ReleaseBaseUrl/$binaryName"
$tempPath    = Join-Path $env:TEMP "$binaryName.download"
Write-State 'Download URL' $downloadUrl

# Force TLS 1.2 on PS 5.1 hosts where it isn't the default.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    Write-Output "WARN: could not enforce TLS 1.2: $($_.Exception.Message)"
}

$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing
} catch {
    Write-Output "FAIL: download failed: $($_.Exception.Message)"
    Write-State 'State' 'download_failed'
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 3
}

if (-not (Test-Path $tempPath)) {
    Write-Output "FAIL: download reported success but $tempPath is missing."
    Write-State 'State' 'download_missing'
    exit 3
}
$downloadedSize = (Get-Item $tempPath).Length
Write-State 'Downloaded bytes' $downloadedSize

# --- Verify PE32+ magic bytes (MZ at offset 0) ---
try {
    $fs = [System.IO.File]::OpenRead($tempPath)
    $header = New-Object byte[] 2
    $null = $fs.Read($header, 0, 2)
    $fs.Close()
} catch {
    Write-Output "FAIL: could not read downloaded file header: $($_.Exception.Message)"
    Write-State 'State' 'header_read_failed'
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 5
}
if ($header[0] -ne 0x4D -or $header[1] -ne 0x5A) {
    Write-Output "FAIL: downloaded file is not a Windows PE (no MZ header)."
    Write-State 'State' 'not_a_pe'
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 5
}

# --- Move into place atomically ---
try {
    Move-Item -Path $tempPath -Destination $targetPath -Force
} catch {
    Write-Output "FAIL: could not move to $targetPath : $($_.Exception.Message)"
    Write-State 'State' 'move_failed'
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    exit 4
}

Write-Output ""
Write-Output "OK: installed."
Write-State 'Installed at' $targetPath
Write-State 'State'        'installed'

Write-Output ""
Write-Output "Next: load via orbit. Interactive test:"
Write-Output "  'C:\Program Files\Orbit\bin\orbit\orbit.exe' shell -- --extension `"$targetPath`" --allow-unsafe"
Write-Output "Then query: SELECT state, state_reason FROM windows_yellowkey;"
exit 0
