<#
.SYNOPSIS
    Installs and runs the windows_yellowkey osquery extension on this host.

.DESCRIPTION
    Under fleetd, orbit owns the osquery autoload set. On every start orbit
    rewrites <root-dir>\extensions.load from the extension set Fleet sends it
    (global or team, delivered through a TUF update server) and only then hands
    osquery --extensions_autoload. With no extension configured there, orbit
    writes an empty file, so anything dropped into extensions.load by hand is
    wiped on the next orbit restart and the table never registers. Setting
    extensions_autoload in agent options does not work either: Fleet rejects it
    because orbit owns that flag.

    This script therefore does not touch extensions.load. An osquery extension
    is a process that connects to osquery's extension socket and registers its
    tables; autoload is only one way to start it. So the script runs the
    extension itself, as a LocalSystem scheduled task that connects to orbit's
    running osquery extension socket and reconnects whenever osquery restarts.
    Bringing the extension up this way needs no TUF server and no orbit restart.

    Steps:
      1. Find the orbit service and resolve orbit's root-dir for the binary
         location, falling back to %ProgramFiles%\Orbit.
      2. Download the architecture-matching binary (amd64 or arm64) and place
         it at <root-dir>\extensions\windows_yellowkey.ext.exe.
      3. Read osquery's extension socket from the running osqueryd command line
         (fallback to orbit's default pipe), then write a supervisor script.
      4. Harden the binary, directory, and runner ACLs (owner Administrators,
         inheritance removed, full control to Administrators and SYSTEM only):
         all three run as SYSTEM, so none may be writable by a non-admin.
      5. Register a LocalSystem scheduled task that runs the supervisor at
         startup, then start it now.

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
      0 = Installed; task created and started, extension process connected
      2 = Unsupported architecture
      3 = Download failed
      4 = Root-dir resolve, placement, runner write, ACL, or task setup failed
      5 = Downloaded file is not a PE
      6 = Task created but the extension had not connected before the timeout
          (the task retries on its own and should connect shortly)

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

$TaskName = 'Fleet windows_yellowkey extension'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-30} : {1}" -f $Label, $Value)
}

function Set-OsquerySafeAcl {
    # The binary and its runner both execute as SYSTEM, so neither may be
    # writable by a non-admin or a standard user could run code as SYSTEM. Set
    # owner Administrators, remove inheritance, and grant full control to
    # Administrators and SYSTEM only. Well-known SIDs avoid name lookups on
    # non-English Windows. Each path is hardened on its own, and /inheritance:r
    # is paired with /grant:r in one call so the object never holds an empty
    # DACL (a directory (OI)(CI) grant would reach a child only as an inherited
    # ACE, which the inheritance strip then removes).
    param([string[]]$Paths)

    $admins = '*S-1-5-32-544'  # BUILTIN\Administrators
    $system = '*S-1-5-18'      # NT AUTHORITY\SYSTEM

    # icacls writes to stderr on per-item errors; with ErrorActionPreference =
    # Stop and 2>&1 that becomes a terminating error before we can read the
    # exit code, so drop to Continue for the calls and check $LASTEXITCODE.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $ok = $true
    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) { continue }
        $flags = if ((Get-Item $p).PSIsContainer) { '(OI)(CI)F' } else { 'F' }
        $out  = & icacls $p /setowner $admins /c /q 2>&1
        $eOwn = $LASTEXITCODE
        $out += & icacls $p /inheritance:r /grant:r "${admins}:${flags}" "${system}:${flags}" /c /q 2>&1
        $eGrant = $LASTEXITCODE
        if ($eOwn -ne 0 -or $eGrant -ne 0) {
            Write-Output ("FAIL: icacls hardening of {0} failed (setowner={1}, grant={2}): {3}" -f `
                $p, $eOwn, $eGrant, (($out | Out-String).Trim()))
            $ok = $false
        }
    }
    $ErrorActionPreference = $prevEAP
    return $ok
}

Write-Output "=== windows_yellowkey extension installer ==="
Write-Output ""

# --- Find the orbit service: it gives the command line (for root-dir) and
#     confirms fleetd is present. fleetd's Windows service is "Fleet osquery". ---
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
    Write-Output "WARN: no orbit/fleetd service found; using default paths."
}

# --- Resolve orbit's root-dir (only to locate the binary; we never write
#     extensions.load). An explicit --root-dir wins; else the orbit.exe lives at
#     <root-dir>\bin\...; else orbit's Windows default is %ProgramFiles%\Orbit. ---
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
    $RootDir = (Resolve-RootDir -Service $svc -Override $RootDir).Trim()
    # orbit is often launched with --root-dir "...\Orbit\."; collapse the \. so
    # the paths we report and harden are clean.
    $RootDir = [System.IO.Path]::GetFullPath($RootDir).TrimEnd('\')
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
# osquery on Windows expects extension binaries to end in .ext.exe.
$installedName = 'windows_yellowkey.ext.exe'
$targetPath    = Join-Path $ExtensionsDir $installedName
$runnerPath    = Join-Path $ExtensionsDir 'windows_yellowkey-runner.ps1'

Write-State 'Root-dir'       $RootDir
Write-State 'Extensions dir' $ExtensionsDir

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

    # curl.exe ships with every YellowKey-affected SKU (Windows 11, Server 2022+).
    # -f fails on HTTP errors like 404, -L follows GitHub's redirect, -s silences
    # the progress meter, -S keeps real error text, --retry rides out transient
    # resets. Invoke-WebRequest is flaky on the GitHub redirect.
    #
    # curl writes to stderr; with ErrorActionPreference = Stop and 2>&1 that
    # becomes a terminating NativeCommandError before we can read the exit code,
    # so drop to Continue for the call and check $LASTEXITCODE instead.
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

# --- Read osquery's extension socket from the running osqueryd ---
# orbit launches osqueryd with --extensions_socket=<pipe>; the extension must
# connect to that same socket. Read it from the live process so a future orbit
# change to the pipe name still works; fall back to orbit's Windows default.
$socket = '\\.\pipe\orbit-osquery-extension'
try {
    $cmd = Get-CimInstance Win32_Process -Filter "Name='osqueryd.exe'" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty CommandLine
    if ($cmd -and ($cmd -match '--extensions_socket=(\S+)')) { $socket = $matches[1] }
} catch {
    Write-Output "WARN: could not read osqueryd command line; using default socket. $($_.Exception.Message)"
}
Write-State 'Extension socket' $socket

# --- Write the supervisor that keeps the extension connected ---
# osquery restarts (orbit reloads, config changes) drop the connection and end
# the extension process, so the supervisor relaunches it. No try/catch: a native
# command failure does not throw with ErrorActionPreference Continue, so the
# loop just falls through to the retry.
$runner = @"
`$ErrorActionPreference = 'Continue'
`$exe    = '$targetPath'
`$socket = '$socket'
while (`$true) {
    & `$exe --socket `$socket --interval 3 --timeout 3 2>&1 | Out-Null
    Start-Sleep -Seconds 5
}
"@
try {
    Set-Content -Path $runnerPath -Value $runner -Encoding ASCII -Force
} catch {
    Write-Output "FAIL: could not write runner $runnerPath : $($_.Exception.Message)"
    Write-State 'State' 'runner_write_failed'
    exit 4
}
Write-State 'Runner' $runnerPath

# --- Harden the binary, runner, and directory so SYSTEM can run them and
#     non-admins cannot tamper with code that executes as SYSTEM ---
if (-not (Set-OsquerySafeAcl -Paths @($ExtensionsDir, $targetPath, $runnerPath))) {
    Write-State 'State' 'acl_hardening_failed'
    exit 4
}
Write-State 'ACL' 'Administrators+SYSTEM only, inheritance removed'

# --- Register and start a LocalSystem scheduled task for the supervisor ---
# Runs at startup and is restarted by Task Scheduler if it ever stops. Run as
# SYSTEM (the well-known account name, locale-independent) so it can reach
# osquery's socket and read privileged state. -Force replaces a prior task so
# re-runs by the policy self-heal; IgnoreNew avoids stacking instances.
try {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument ("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"{0}`"" -f $runnerPath)
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -MultipleInstances IgnoreNew `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
} catch {
    Write-Output "FAIL: could not register or start scheduled task '$TaskName': $($_.Exception.Message)"
    Write-State 'State' 'task_setup_failed'
    exit 4
}
Write-State 'Scheduled task' "$TaskName (LocalSystem, at startup)"

# --- Confirm the extension process connected ---
$proc = $null
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 2
    $proc = Get-Process -Name 'windows_yellowkey*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $proc) { break }
}

Write-Output ""
if ($null -ne $proc) {
    Write-State 'Extension process' ("running (PID {0})" -f $proc.Id)
    Write-Output "OK: extension running as a LocalSystem task and connected to osquery."
    Write-Output "    The task relaunches it whenever osquery restarts. Verify in Fleet:"
    Write-Output "      SELECT 1 FROM osquery_registry WHERE registry = 'table'"
    Write-Output "        AND name = 'windows_yellowkey' AND active = 1;"
    Write-Output "      SELECT state FROM windows_yellowkey;"
    Write-State 'State' 'installed'
    exit 0
} else {
    Write-Output "WARN: task created but no extension process yet. osquery may be down or"
    Write-Output "      starting; the task retries every few seconds and should connect."
    Write-State 'State' 'task_started_not_yet_connected'
    exit 6
}
