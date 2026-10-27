# Lab only: copies the package from a USB drive to C:\Windows\Temp, where scripts/stage-ppkg.ps1 picks it up. After a
# reset the guest agent is gone, so a hot-plugged USB drive and a Fleet script replace tools/qga-push.sh.
$ErrorActionPreference = 'Stop'
$f = Get-PSDrive -PSProvider FileSystem | ForEach-Object { Get-ChildItem "$($_.Root)fleet-agent-*.ppkg" -ErrorAction SilentlyContinue } | Select-Object -First 1
if (-not $f) { Write-Output 'no package on any drive'; exit 1 }
Copy-Item $f.FullName 'C:\Windows\Temp\fleet-agent.ppkg' -Force
"$($f.FullName) -> C:\Windows\Temp\fleet-agent.ppkg $((Get-FileHash 'C:\Windows\Temp\fleet-agent.ppkg').Hash)"
