# Stages Fleet's provisioning package in C:\Recovery\Customizations, which push-button reset re-applies after a reset
# (Microsoft "Recovery components"). Same pattern as Omnissa's DeviceWipewProvisioning.ps1 for Workspace ONE.
# The lab pushes the .ppkg to C:\Windows\Temp first; a production version would download it or ship it as a package.
$ErrorActionPreference = 'Stop'
$src = 'C:\Windows\Temp\fleet-agent.ppkg'
$dst = 'C:\Recovery\Customizations'
if (-not (Test-Path $src)) { Write-Output "missing $src"; exit 1 }
if (-not (Test-Path 'C:\Recovery')) { New-Item -ItemType Directory 'C:\Recovery' | Out-Null }
# Microsoft's recommended permissions for C:\Recovery: SYSTEM and Administrators only, owned by Administrators, hidden.
& icacls C:\Recovery /inheritance:r | Out-Null
& icacls C:\Recovery /grant:r 'SYSTEM:(OI)(CI)(F)' | Out-Null
& icacls C:\Recovery /grant:r '*S-1-5-32-544:(OI)(CI)(F)' | Out-Null
# The package holds the enroll secret. Windows can leave explicit read grants on C:\Recovery that /inheritance:r keeps
# (v1 W-6), so remove Users, Authenticated Users, and Everyone by name.
& icacls C:\Recovery /remove:g '*S-1-5-32-545' '*S-1-5-11' '*S-1-1-0' | Out-Null
& takeown /f C:\Recovery /a | Out-Null
& attrib +H C:\Recovery
New-Item -ItemType Directory -Force $dst | Out-Null
Get-ChildItem $dst -Filter *.ppkg -ErrorAction SilentlyContinue | Remove-Item -Force
Copy-Item $src "$dst\fleet-agent.ppkg" -Force
Get-ChildItem $dst | ForEach-Object { "$($_.FullName) $($_.Length) $((Get-FileHash $_.FullName).Hash)" }
& icacls C:\Recovery
