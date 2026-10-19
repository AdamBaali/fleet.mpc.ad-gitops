<#
.SYNOPSIS
    Installs and loads the software_itam osquery extension on this host
    (fleetdm/fleet#38864).

.DESCRIPTION
    Fleet run_script remediation for the software-itam-extension policy.
    The policy fails when the software_itam table is not registered.

    Why a pinned commit and SHA-256: the binary runs as SYSTEM on every
    host in the fleet. Pinning means a change upstream can't reach hosts
    until someone updates these values here, through a reviewed GitOps
    change.

    Why the file name carries the hash: a running extension locks its
    .exe, so an upgrade writes a new file next to it and points
    extensions.load at the new one. The next run deletes old copies once
    they are unlocked. No service stop is needed to swap files.

    Why C:\Program Files\osquery\extensions.load: it is osquery's
    compiled-in default autoload file on Windows, used when orbit passes no
    --extensions_autoload. Orbit's own extensions.load is managed by
    Fleet's agent_options.extensions and is emptied when that is unset.
    The ACL and ASCII loader handling follow the windows_yellowkey
    installer in this repo.

.NOTES
    Exit codes:
      0 = Installed (or already current); restart scheduled when anything changed
      3 = Fleet osquery service not present
      4 = Filesystem operation failed (directory, move, loader write, ACL)
      6 = Download failed or checksum mismatch
      8 = Unsupported architecture
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ExtensionName = 'software_itam'
$ExtCommit     = '__EXT_COMMIT__'
$BaseUrl       = "https://raw.githubusercontent.com/AdamBaali/fleet-extensions/$ExtCommit/software_itam"
$Assets = @{
    'AMD64' = @{ File = 'software_itam-amd64.exe'; Sha256 = '__SHA256_WINDOWS_AMD64__' }
    'ARM64' = @{ File = 'software_itam-arm64.exe'; Sha256 = '__SHA256_WINDOWS_ARM64__' }
}

$OsqueryHome   = 'C:\Program Files\osquery'
$ExtensionsDir = Join-Path $OsqueryHome 'extensions'
$LoaderPath    = Join-Path $OsqueryHome 'extensions.load'
$ServiceName   = 'Fleet osquery'

function Write-State {
    param([string]$Label, [string]$Value)
    Write-Output ("{0,-20} : {1}" -f $Label, $Value)
}

function Set-HardenedAcl {
    # Owner Administrators, no inherited ACEs, full control for SYSTEM and
    # Administrators, read+execute for Users. Well-known SIDs so this works
    # on non-English Windows. osquery refuses extensions others can write.
    param([string]$Path, [bool]$IsDirectory)

    $systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $adminsSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $usersSid  = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')

    $acl = Get-Acl -Path $Path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($r in @($acl.Access)) { [void]$acl.RemoveAccessRule($r) }
    $acl.SetOwner($adminsSid)
    $inherit = if ($IsDirectory) {
        [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    } else {
        [System.Security.AccessControl.InheritanceFlags]::None
    }
    foreach ($rule in @(
        [System.Security.AccessControl.FileSystemAccessRule]::new($systemSid, 'FullControl', $inherit, 'None', 'Allow'),
        [System.Security.AccessControl.FileSystemAccessRule]::new($adminsSid, 'FullControl', $inherit, 'None', 'Allow'),
        [System.Security.AccessControl.FileSystemAccessRule]::new($usersSid, 'ReadAndExecute', $inherit, 'None', 'Allow')
    )) { $acl.AddAccessRule($rule) }
    Set-Acl -Path $Path -AclObject $acl
}

Write-Output "=== $ExtensionName extension installer ==="

if ($null -eq (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    Write-Output "FAIL: service '$ServiceName' not found. Is fleetd installed?"
    exit 3
}

$arch = $env:PROCESSOR_ARCHITECTURE
if (-not $Assets.ContainsKey($arch)) {
    Write-Output "FAIL: unsupported architecture: $arch"
    exit 8
}
$asset = $Assets[$arch]
$want = $asset.Sha256.ToLowerInvariant()
$ExtensionPath = Join-Path $ExtensionsDir ("{0}-{1}.ext.exe" -f $ExtensionName, $want.Substring(0, 12))
Write-State 'Architecture' $arch
Write-State 'Target' $ExtensionPath

try {
    foreach ($dir in @($OsqueryHome, $ExtensionsDir)) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-HardenedAcl -Path $dir -IsDirectory $true
    }
} catch {
    Write-Output "FAIL: could not prepare ${ExtensionsDir}: $($_.Exception.Message)"
    exit 4
}

$changed = $false
$have = ''
if (Test-Path $ExtensionPath) { $have = (Get-FileHash -Algorithm SHA256 -Path $ExtensionPath).Hash.ToLowerInvariant() }

if ($have -eq $want) {
    Write-State 'Binary' 'already current'
} else {
    $tempPath = Join-Path $env:TEMP "$ExtensionName-$([guid]::NewGuid()).download"
    try {
        Invoke-WebRequest -Uri "$BaseUrl/$($asset.File)" -OutFile $tempPath -UseBasicParsing -TimeoutSec 120
    } catch {
        Write-Output "FAIL: download failed: $($_.Exception.Message)"
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        exit 6
    }
    $got = (Get-FileHash -Algorithm SHA256 -Path $tempPath).Hash.ToLowerInvariant()
    if ($got -ne $want) {
        Write-Output "FAIL: checksum mismatch: got $got, want $want"
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        exit 6
    }
    try {
        Move-Item -Path $tempPath -Destination $ExtensionPath -Force
        Set-HardenedAcl -Path $ExtensionPath -IsDirectory $false
    } catch {
        Write-Output "FAIL: could not place ${ExtensionPath}: $($_.Exception.Message)"
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        exit 4
    }
    Write-State 'Binary' "installed ($want)"
    $changed = $true
}

# Point the loader at this build only. Other extensions' lines stay.
$lines = @()
if (Test-Path $LoaderPath) {
    $lines = @(Get-Content -Path $LoaderPath -ErrorAction SilentlyContinue | Where-Object { $_ -and $_.Trim() -ne '' })
}
$others = @($lines | Where-Object { (Split-Path $_ -Leaf) -notlike "$ExtensionName*" })
$wanted = $others + $ExtensionPath
if (($lines -join "`n") -ne ($wanted -join "`n")) {
    try {
        # ASCII without a BOM: osquery skips a UTF-16 or UTF-8-BOM loader.
        [System.IO.File]::WriteAllLines($LoaderPath, [string[]]$wanted, [System.Text.ASCIIEncoding]::new())
        Set-HardenedAcl -Path $LoaderPath -IsDirectory $false
    } catch {
        Write-Output "FAIL: could not write ${LoaderPath}: $($_.Exception.Message)"
        exit 4
    }
    Write-State 'extensions.load' 'updated'
    $changed = $true
} else {
    Write-State 'extensions.load' 'already current'
}

# Old builds are unlocked once osqueryd restarted on the new one.
Get-ChildItem -Path $ExtensionsDir -Filter "$ExtensionName-*.ext.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $ExtensionPath } |
    ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }

if ($changed) {
    # orbit runs this script, so restarting its service now would stop the
    # script before orbit sends the result to Fleet. A detached process
    # restarts it 30 seconds after this script exits.
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-NonInteractive', '-Command',
        "Start-Sleep -Seconds 30; Restart-Service -Name '$ServiceName' -Force"
    )
    Write-State 'Service' 'restart scheduled in 30 seconds'
}

Write-Output "OK. Verify: SELECT 1 FROM osquery_registry WHERE registry = 'table' AND name = '$ExtensionName' AND active = 1;"
exit 0
