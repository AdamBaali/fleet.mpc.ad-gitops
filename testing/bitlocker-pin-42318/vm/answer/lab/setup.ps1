param([string]$Root)
# First-logon setup for the #42318 BitLocker lab VM. Runs once, logs to C:\Users\Public\setup.log.
$ErrorActionPreference = 'Continue'
"start $(Get-Date -Format o) root=$Root"
powercfg -h off
# Guest tools (qemu-ga, SPICE, virtio-net) so the Mac can run commands in the guest with utmctl exec.
$gt = Get-ChildItem -Path $Root -Filter 'utm-guest-tools-*.exe' | Select-Object -First 1
if ($gt) { "installing $($gt.Name)"; Start-Process -FilePath $gt.FullName -ArgumentList '/S' -Wait; "guest tools exit=$LASTEXITCODE" }
powercfg /change monitor-timeout-ac 0; powercfg /change standby-timeout-ac 0
# Baseline before Fleet: TPM, edition, BitLocker state (no recovery keys are printed by these).
"--- Get-Tpm"; Get-Tpm | Format-List TpmPresent,TpmReady,TpmEnabled,TpmActivated,TpmOwned,ManufacturerIdTxt,ManufacturerVersion
"--- edition"; (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion') | Format-List EditionID,DisplayVersion,CurrentBuild,UBR
"--- manage-bde -status C:"; manage-bde -status C:
# From the next boot on, sign in automatically as the standard user "labuser" (the customer's users aren't admins).
$w = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty $w AutoAdminLogon '1'; Set-ItemProperty $w DefaultUserName 'labuser'; Set-ItemProperty $w DefaultPassword ''
Remove-ItemProperty $w AutoLogonCount -ErrorAction SilentlyContinue
"autologon -> labuser"
New-Item -ItemType File -Path C:\Users\Public\setup-done.txt -Force | Out-Null
"done $(Get-Date -Format o)"
