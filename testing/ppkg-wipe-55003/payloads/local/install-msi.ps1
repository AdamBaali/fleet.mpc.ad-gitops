# Lab only: installs the fleetd MSI pushed to C:\Windows\Temp, as a brownfield host would have it.
$p = Start-Process msiexec.exe -ArgumentList '/i', 'C:\Windows\Temp\fleet-osquery-arm64.msi', '/qn', '/norestart' -Wait -PassThru
"msiexec exit $($p.ExitCode)"
Start-Sleep 20
Get-Service *osquery* | ForEach-Object { "$($_.Name) $($_.Status)" }
