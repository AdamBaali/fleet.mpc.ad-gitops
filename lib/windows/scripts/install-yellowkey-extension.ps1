<#
.SYNOPSIS
    Installs and loads the windows_yellowkey osquery extension on this host.

.DESCRIPTION
    Under fleetd, orbit decides osquery's flags. At startup orbit stats
    <root-dir>\extensions.load and, only when that file exists and is
    non-empty, hands osquery --extensions_autoload for it
    (orbit/cmd/orbit/orbit.go). Setting extensions_autoload in Fleet agent
    options does not work: Fleet rejects it because orbit owns that flag. So
    the one supported path is to write the extension into orbit's own
    extensions.load and restart orbit.

    The failure this script guards against: if extensions.load is written to
    the wrong directory, orbit never sees it and osquery falls back to its
    compiled default (C:\Program Files\osquery\extensions.load), which does
    not exist under fleetd, so nothing loads. This script therefore resolves
    orbit's real root-dir instead of assuming it.

    Steps:
      1. Find the orbit service and resolve orbit's root-dir from its
         command line (--root-dir, else the orbit.exe location), falling
         back to %ProgramFiles%\Orbit.
      2. Download the architecture-matching binary (amd64 or arm64) and place
         it at <root-dir>\extensions\windows_yellowkey.ext.exe.
      3. Harden the extensions directory ACL (owner Administrators, inheritance
         removed, write limited to Administrators and SYSTEM) so osquery's
         safe-permission check accepts the binary. orbit does not pass
         --allow_unsafe, so without this osquery silently skips it.
      4. Write that path into <root-dir>\extensions.load and confirm the file
         is non-empty (orbit's load condition).
      5. Restart the orbit service so orbit re-reads the file.

    Attached as the run_script remediation for the windows-yellowkey-extension
    policy, which fails when the windows_yellowkey table is not registered.

.PARAMETER BaseUrl
    Base URL for the binary. Default: the prebuilt binaries committed under
    extensions/windows_yellowkey/ on the repo's main branch
    (raw.githubusercontent.com). Override for an internal mirror or a
    private-repo raw URL + token.

.PARAMETER RootDir
    orbit root-dir override. Default: auto-detected from the orbit service.

.PARAMETER ServiceName
    orbit service name override. Default: auto-detected.

.OUTPUTS
    Structured key:value output to stdout for log capture.

.NOTES
    Exit codes:
      0 = Installed, written into extensions.load, orbit restarted
      2 = Unsupported architecture
      3 = Download failed
      4 = Root-dir resolve, placement, ACL hardening, or autoload write failed
      5 = Downloaded file is not a PE
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
    [string]$RootDir = '',

    [Parameter(Mandatory = $false)]
    [string]$ServiceName = ''
)

$ErrorActionPreference = 'Stop'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

function Set-OsquerySafeAcl {
    # osquery's Windows safe-permission check refuses an autoloaded extension
    # whose DACL is inherited, or writable by anyone but the owner. Set the
    # extensions directory and the binary to owner Administrators, inheritance
    # removed, explicit full control for Administrators and SYSTEM only.
    # osqueryd runs as LocalSystem, so SYSTEM needs an explicit ACE on the file.
    # Well-known SIDs avoid name lookups on non-English Windows.
    #
    # The file is hardened on its own, not through the directory. A (OI)(CI)
    # grant on the directory reaches the file only as an inherited ACE, and the
    # /inheritance:r that follows then strips it, leaving the file with an empty
    # DACL that denies SYSTEM and silently blocks the load. Pairing
    # /inheritance:r with /grant:r in one call keeps the object from ever
    # holding an empty DACL.
    param([string]$Dir, [string]$File)

    $admins = '*S-1-5-32-544'  # BUILTIN\Administrators
    $system = '*S-1-5-18'      # NT AUTHORITY\SYSTEM

    # icacls writes to stderr on per-item errors; with ErrorActionPreference =
    # Stop and 2>&1 that becomes a terminating error before we can read the
    # exit code, so drop to Continue for the calls and check $LASTEXITCODE.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out   = & icacls $Dir  /setowner $admins /t /c /q 2>&1
    $eOwn  = $LASTEXITCODE
    $out  += & icacls $Dir  /inheritance:r /grant:r "${admins}:(OI)(CI)F" "${system}:(OI)(CI)F" /c /q 2>&1
    $eDir  = $LASTEXITCODE
    $out  += & icacls $File /inheritance:r /grant:r "${admins}:F" "${system}:F" /c /q 2>&1
    $eFile = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($eOwn -ne 0 -or $eDir -ne 0 -or $eFile -ne 0) {
        Write-Output ("FAIL: icacls hardening failed (setowner={0}, dir={1}, file={2}): {3}" -f `
            $eOwn, $eDir, $eFile, (($out | Out-String).Trim()))
        return $false
    }
    return $true
}

Write-Output "=== windows_yellowkey extension installer ==="
Write-Output ""

# --- Find the orbit service: it gives both the command line (for root-dir)
#     and the name to restart. fleetd's Windows service is "Fleet osquery". ---
$svc = $null
try {
    if ($ServiceName) {
        $svc = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
    } else {
        $svc = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)orbit|fleet' -or $_.DisplayName -match '(?i)orbit|fleet' } |
            Select-Object -First 1
    }
} catch {
    Write-Output "WARN: could not enumerate services: $($_.Exception.Message)"
}
if ($null -ne $svc) {
    Write-State 'orbit service' ("{0} ({1})" -f $svc.Name, $svc.State)
} else {
    Write-Output "WARN: no orbit/fleetd service found; using default paths and known service names."
}

# --- Resolve orbit's root-dir the same way orbit does ---
# An explicit --root-dir wins; otherwise the orbit.exe lives at <root-dir>\bin\...;
# otherwise orbit's Windows default is %ProgramFiles%\Orbit.
function Resolve-RootDir {
    param($Service, [string]$Override)
    if ($Override) { return $Override }
    if ($null -ne $Service -and $Service.PathName) {
        $p = $Service.PathName
        if (($p -match '--root-dir\s+"([^"]+)"') -or ($p -match '--root-dir\s+(\S+)')) {
            return $matches[1]
        }
        $exe = $null
        if (($p -match '^\s*"([^"]+\.exe)"') -or ($p -match '^\s*(\S+\.exe)')) { $exe = $matches[1] }
        if ($exe) {
            $i = $exe.ToLower().IndexOf('\bin\')
            if ($i -gt 0) { return $exe.Substring(0, $i) }
        }
    }
    return (Join-Path $env:ProgramFiles 'Orbit')
}

try {
    $RootDir = (Resolve-RootDir -Service $svc -Override $RootDir).Trim().TrimEnd('\')
} catch {
    Write-Output "FAIL: could not resolve orbit root-dir: $($_.Exception.Message)"
    Write-State 'State' 'rootdir_unresolved'
    exit 4
}
if (-not (Test-Path $RootDir)) {
    $fallback = (Join-Path $env:ProgramFiles 'Orbit')
    Write-Output "WARN: resolved root-dir '$RootDir' does not exist; falling back to '$fallback'."
    $RootDir = $fallback
}

$ExtensionsDir = Join-Path $RootDir 'extensions'
$AutoloadFile  = Join-Path $RootDir 'extensions.load'
# osquery on Windows expects extension binaries to end in .ext.exe.
$installedName = 'windows_yellowkey.ext.exe'
$targetPath    = Join-Path $ExtensionsDir $installedName

Write-State 'Root-dir'       $RootDir
Write-State 'Extensions dir' $ExtensionsDir
Write-State 'Autoload file'  $AutoloadFile

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

    # curl.exe ships with every YellowKey-affected SKU (Windows 10 1803+,
    # Server 2019+). -f fails on HTTP errors like 404, -L follows GitHub's
    # redirect, -s silences the progress meter, -S keeps real error text,
    # --retry rides out transient resets. Invoke-WebRequest is flaky on the
    # GitHub redirect and reports "connection closed".
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

    # Verify PE magic bytes (MZ at offset 0).
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

# --- Harden the extensions directory so osquery will load the binary ---
# orbit does not pass --allow_unsafe, so osquery applies its safe-permission
# check to the autoloaded extension. On Windows the inherited Program Files
# ACLs do not satisfy it; the owner must be Administrators with inheritance
# stripped. Without this osquery silently skips the extension and the table
# never registers. Runs on every invocation so a prior partial run self-heals.
if (-not (Set-OsquerySafeAcl -Dir $ExtensionsDir -File $targetPath)) {
    Write-State 'State' 'acl_hardening_failed'
    exit 4
}
Write-State 'ACL' 'Administrators+SYSTEM only, inheritance removed'

# --- Write the binary path into <root-dir>\extensions.load ---
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

# orbit only adds --extensions_autoload when the file exists and size > 0.
$autoloadSize = 0
if (Test-Path $AutoloadFile) { $autoloadSize = (Get-Item $AutoloadFile).Length }
if ($autoloadSize -le 0) {
    Write-Output "FAIL: $AutoloadFile is empty; orbit will not pass --extensions_autoload."
    Write-State 'State' 'autoload_empty'
    exit 4
}
Write-State 'Autoload size' ("{0} bytes" -f $autoloadSize)

# --- Restart orbit so it re-reads extensions.load ---
# Runs on every invocation: the policy only calls this script when the
# extension is not loaded, so reaching here means the load needs (re)applying.
$restartName = $null
if ($null -ne $svc) { $restartName = $svc.Name }
if (-not $restartName) {
    foreach ($n in @('Fleet osquery', 'Orbit', 'orbit', 'fleetd')) {
        if (Get-Service -Name $n -ErrorAction SilentlyContinue) { $restartName = $n; break }
    }
}
if (-not $restartName) {
    Write-Output "WARN: orbit service not found; binary placed and registered."
    Write-Output "      Restart orbit/fleetd to load the extension."
    Write-State 'State' 'placed_restart_deferred'
    exit 6
}
try {
    Restart-Service -Name $restartName -Force
    Write-State 'Restarted service' $restartName
} catch {
    Write-Output "WARN: could not restart '$restartName': $($_.Exception.Message)"
    Write-Output "      Binary placed and registered; restart orbit to load."
    Write-State 'State' 'placed_restart_failed'
    exit 6
}

Write-Output ""
Write-Output "OK: extension placed, written into extensions.load, orbit restarted."
Write-Output "    orbit re-reads $AutoloadFile at startup and hands osquery"
Write-Output "    --extensions_autoload for it. Give osquery ~30s, then verify:"
Write-Output "      SELECT name, value FROM osquery_flags WHERE name = 'extensions_autoload';"
Write-Output "        -> expect $AutoloadFile (not the osquery default)"
Write-Output "      SELECT state FROM windows_yellowkey;"
Write-Output "    If the table is missing, check osquery's log for 'unsafe"
Write-Output "    permissions' on the binary; the ACL step above is what prevents that."
Write-Output "    Local check: & '$RootDir\bin\orbit\orbit.exe' shell -- --extension `"$targetPath`" --allow-unsafe"
Write-Output "    (note: --allow-unsafe bypasses the permission check, so a passing"
Write-Output "    local shell does not prove the autoloaded extension will load)."
Write-State 'State' 'installed'
exit 0
