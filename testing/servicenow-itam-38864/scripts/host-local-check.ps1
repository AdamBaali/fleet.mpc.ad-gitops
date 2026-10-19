<#
.SYNOPSIS
    On-host truth for the Windows ITAM tests (S-1, W-*, X-2, X-3, C-*). Run elevated from a checkout of this repo.

.DESCRIPTION
    Usage: .\host-local-check.ps1 [-OutDir <dir>]
    Runs every report in lib\windows\reports\software-itam.reports.yml and SELECT * FROM software_itam
    with fleetd's own osqueryd in shell mode. Writes one JSON file per query and prints rows and seconds.
#>
[CmdletBinding()]
param([string]$OutDir)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot "..\test-evidence\local\$($env:COMPUTERNAME.ToLower())" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Osq = Get-ChildItem 'C:\Program Files\Orbit\bin\osqueryd\windows*\*\osqueryd.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $Osq) { throw 'osqueryd.exe not found under C:\Program Files\Orbit\bin\osqueryd' }
$Loader = 'C:\Program Files\osquery\extensions.load'
$Ext = if (Test-Path $Loader) { Get-Content $Loader | Where-Object { $_ -match 'software_itam' } | Select-Object -First 1 } else { $null }

# The repo's report YAML: "- name:" items, each with a "query: |" block indented four spaces.
function Get-Reports($Path) {
    $out = @(); $name = $null; $q = ''; $inq = $false
    foreach ($line in Get-Content $Path) {
        if ($line -match '^- name: (.+)$') { if ($name) { $out += ,@($name, $q) }; $name = $Matches[1]; $q = ''; $inq = $false; continue }
        if ($line -match '^  query: \|') { $inq = $true; continue }
        if ($inq -and $line -match '^    (.*)$') { $q += ' ' + $Matches[1]; continue }
        if ($inq) { $inq = $false }
    }
    if ($name) { $out += ,@($name, $q) }
    return $out
}

function Invoke-Q($Label, $Sql) {
    $file = Join-Path $OutDir (($Label.ToLower() -replace '[^a-z0-9]+', '-') + '.json')
    $args = @('-S', '--json')
    if ($Ext) { $args += @('--extension', $Ext, '--allow_unsafe') }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $json = & $Osq.FullName @args $Sql 2>$null
    $sw.Stop()
    $json | Out-File -Encoding utf8 $file
    $rows = try { (($json -join "`n") | ConvertFrom-Json).Count } catch { 0 }
    '{0,-50} rows={1,-6} seconds={2:N1}' -f $Label, $rows, $sw.Elapsed.TotalSeconds
}

Write-Output "osqueryd: $($Osq.FullName)"
foreach ($r in Get-Reports (Join-Path $Root 'lib\windows\reports\software-itam.reports.yml')) { Invoke-Q $r[0] $r[1] }
if ($Ext) { Invoke-Q 'ITAM software (extension)' 'SELECT * FROM software_itam;' }
else { Write-Output "software_itam not listed in $Loader : extension checks skipped" }
Invoke-Q 'native programs count' 'SELECT COUNT(*) AS n FROM programs;'
Write-Output "outputs in $OutDir"
