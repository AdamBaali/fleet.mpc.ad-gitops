# Opens the Fleet My device page for this host in Edge. The device token stays on the host; nothing is printed.
$t = (Get-Content 'C:\Program Files\Orbit\identifier' -Raw).Trim()
Start-Process msedge.exe -ArgumentList @('--no-first-run', '--start-maximized', ('https://fleet.mpc.ad/device/' + $t))
