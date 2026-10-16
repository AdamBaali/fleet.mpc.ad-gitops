param([string]$Root)
# First-logon lab setup for the #54654 Windows VM. Runs once, logs to C:\Users\Public\setup.log.
$ErrorActionPreference = 'Continue'
"start $(Get-Date -Format o) root=$Root"
powercfg -h off
$gt = Get-ChildItem -Path $Root -Filter 'utm-guest-tools-*.exe' | Select-Object -First 1
if ($gt) { "installing $($gt.Name)"; Start-Process -FilePath $gt.FullName -ArgumentList '/S' -Wait; "guest tools exit=$LASTEXITCODE" }
Add-Content -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Value "192.168.64.1 ping.lab"
powercfg /change monitor-timeout-ac 0; powercfg /change standby-timeout-ac 0
"--- arch"; $env:PROCESSOR_ARCHITECTURE; (Get-CimInstance Win32_Processor).Name
Import-Certificate -FilePath "$Root\lab\step-ca-root.crt" -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
"installing fleetd"; Start-Process msiexec.exe -ArgumentList '/i',"$Root\lab\fleet-osquery-arm64.msi",'/qn' -Wait; "fleetd exit=$LASTEXITCODE"
New-Item -ItemType File -Path C:\Users\Public\setup-done.txt -Force | Out-Null
"done $(Get-Date -Format o)"
