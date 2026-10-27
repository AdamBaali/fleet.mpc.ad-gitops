# Removes UTM guest-tools drivers except NetKVM (network) and vioserial (guest agent), logging to C:\Windows\Temp\rm.log.
# Runs detached because removing the display and input drivers can stall the guest agent call that starts it.
$keep = 'netkvm.inf', 'vioser.inf'
$log = 'C:\Windows\Temp\rm.log'
Get-WindowsDriver -Online | Where-Object { $_.ProviderName -eq 'Red Hat, Inc.' } | ForEach-Object {
  $orig = Split-Path $_.OriginalFileName -Leaf
  if ($keep -notcontains $orig) {
    $o = pnputil /delete-driver $_.Driver /uninstall /force 2>&1 | Out-String
    Add-Content $log ("{0} ({1}): {2}" -f $_.Driver, $orig, ($o -replace '\s+', ' '))
  }
}
foreach ($s in 'BalloonService', 'spice-webdavd') { Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue }
Add-Content $log 'done'
