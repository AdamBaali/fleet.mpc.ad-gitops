# Lab only: opens a URL in Edge in the interactive setup session (user defaultuser0), from the guest agent's
# SYSTEM context. Stands in for fleetd opening the sign-in page when a lab restart stopped it from doing so.
param([string]$Url)
$user = (Get-CimInstance Win32_ComputerSystem).UserName
$a = New-ScheduledTaskAction -Execute 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -Argument $Url
$p = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive
Register-ScheduledTask -TaskName LabOpenUrl -Action $a -Principal $p -Force | Out-Null
Start-ScheduledTask -TaskName LabOpenUrl
Start-Sleep 3
Unregister-ScheduledTask -TaskName LabOpenUrl -Confirm:$false
"opened for $user"
