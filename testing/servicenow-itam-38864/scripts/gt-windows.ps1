<#
.SYNOPSIS
    Ground truth for the Windows ITAM tests (W-1 to W-4, U-1, U-4). Run in an elevated PowerShell.

.DESCRIPTION
    Usage: .\gt-windows.ps1 -Action <action>
      msi-install   install MSI_OLD silently (W-1)
      msi-upgrade   install MSI_NEW over it (W-4)
      exe-install   install EXE with winget when present, else the vendor installer (W-1)
      open          start each test program for 15 s (W-2)
      uninstall     remove the MSI program (U-1)
      reinstall     install MSI_NEW again after uninstall (U-4)
      facts         print the Prefetch setting W-2 depends on
    Each action appends to ..\ground-truth\<host>.tsv with the UTC time, before anyone reads Fleet.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Action)
$ErrorActionPreference = 'Stop'

# ---- Test programs (change here). Publishers are company or project names. ----
$MsiApp = 'VLC media player'; $MsiPublisher = 'VideoLAN'
# VideoLAN published no win64 MSI for 3.0.21, so the upgrade pair is 3.0.19 to 3.0.20.
$MsiOldVer = '3.0.19'; $MsiOld = 'https://download.videolan.org/pub/videolan/vlc/3.0.19/win64/vlc-3.0.19-win64.msi'
$MsiNewVer = '3.0.20'; $MsiNew = 'https://download.videolan.org/pub/videolan/vlc/3.0.20/win64/vlc-3.0.20-win64.msi'
$MsiExe = 'C:\Program Files\VideoLAN\VLC\vlc.exe'
$ExeApp = 'Notepad++'; $ExePublisher = 'Notepad++ Team'; $ExeWingetId = 'Notepad++.Notepad++'
$ExeUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.7.1/npp.8.7.1.Installer.x64.exe'
$ExeExe = 'C:\Program Files\Notepad++\notepad++.exe'
# --------------------------------------------------------------------------------

$GtDir = if ($env:GT_DIR) { $env:GT_DIR } else { Join-Path $PSScriptRoot '..\ground-truth' }
$GtHost = $env:COMPUTERNAME.ToLower()
$GtFile = Join-Path $GtDir "$GtHost.tsv"

function Record($TestId, $App, $Key, $Version, $Method, $Event, $Publisher = '', $Note = '') {
    New-Item -ItemType Directory -Force -Path $GtDir | Out-Null
    if (-not (Test-Path $GtFile)) {
        "test_id`thost`tos`tapp`tkey`tversion`tmethod`tevent`tutc`texpected_publisher`tnote" | Out-File -Encoding ascii $GtFile
    }
    $utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    "$TestId`t$GtHost`twindows`t$App`t$Key`t$Version`t$Method`t$Event`t$utc`t$Publisher`t$Note" | Out-File -Append -Encoding ascii $GtFile
    Write-Output "recorded $Event $App at $utc -> $GtFile"
}

function Get-Program($Name) {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "$Name*" } | Select-Object -First 1
}

function Install-Msi($Url, $TestId, $Event) {
    $f = Join-Path $env:TEMP 'itam-test.msi'
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $f
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$f`" /qn /norestart" -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "msiexec exit $($p.ExitCode)" }
    $prog = Get-Program $MsiApp
    Record $TestId $MsiApp $MsiApp $prog.DisplayVersion msi $Event $MsiPublisher
}

switch ($Action) {
    'msi-install' { Install-Msi $MsiOld 'W-1' 'install' }
    'msi-upgrade' { Install-Msi $MsiNew 'W-4' 'upgrade' }
    'reinstall'   { Install-Msi $MsiNew 'U-4' 'reinstall' }
    'exe-install' {
        $method = 'exe'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id $ExeWingetId --silent --accept-package-agreements --accept-source-agreements | Out-Null
            $method = 'winget'
        } else {
            $f = Join-Path $env:TEMP 'itam-test.exe'
            Invoke-WebRequest -UseBasicParsing -Uri $ExeUrl -OutFile $f
            Start-Process $f -ArgumentList '/S' -Wait
        }
        $prog = Get-Program $ExeApp
        Record 'W-1' $ExeApp $ExeApp $prog.DisplayVersion $method 'install' $ExePublisher
    }
    'open' {
        foreach ($t in @(@($MsiApp, $MsiExe), @($ExeApp, $ExeExe))) {
            if (Test-Path $t[1]) {
                $p = Start-Process $t[1] -PassThru
                Record 'W-2' $t[0] $t[0] (Get-Program $t[0]).DisplayVersion start 'open'
                Start-Sleep 15
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            }
        }
    }
    'uninstall' {
        $prog = Get-Program $MsiApp
        if ($prog.PSChildName -match '^\{') {
            Start-Process msiexec.exe -ArgumentList "/x $($prog.PSChildName) /qn /norestart" -Wait
        } elseif ($prog.UninstallString) {
            Start-Process cmd.exe -ArgumentList "/c `"$($prog.UninstallString)`" /S" -Wait
        }
        Record 'U-1' $MsiApp $MsiApp '' msiexec 'uninstall'
    }
    'facts' {
        Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' |
            Select-Object EnablePrefetcher
        (Get-CimInstance Win32_OperatingSystem).Caption
    }
    default { Get-Help $PSCommandPath -Detailed }
}
