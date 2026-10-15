# fleetdm/fleet#27903 checks: encryption mode of each volume, protector types (never keys), the OSEncryptionType policy,
# fleetd's encryption-mode log lines, and the BitLocker CSP's own status. Read-only.
"=== time"; Get-Date -Format o
"=== manage-bde -status"; manage-bde -status
"=== volumes (no keys)"; Get-BitLockerVolume | Format-Table -AutoSize MountPoint,VolumeType,VolumeStatus,EncryptionPercentage,EncryptionMethod,ProtectionStatus,@{n="Protectors";e={($_.KeyProtector.KeyProtectorType) -join "+"}}
"=== FVE policy (HKLM\SOFTWARE\Policies\Microsoft\FVE)"; reg query HKLM\SOFTWARE\Policies\Microsoft\FVE 2>&1
"=== MDM PolicyManager BitLocker"; reg query HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\BitLocker 2>&1
"=== fleetd log: encryption mode and BitLocker lines"
$log = Get-ChildItem -Path "$env:windir\system32\config\systemprofile\AppData\Local\FleetDM\Orbit\Logs" -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
if ($log) { $log.FullName; Select-String -Path $log.FullName -Pattern "OSEncryptionType|encrypt|bitlocker|decrypt" | Select-Object -Last 25 | ForEach-Object { $_.Line } } else { "fleetd log not found" }
"=== BitLocker-API events, last 15"; Get-WinEvent -LogName 'Microsoft-Windows-BitLocker/BitLocker Management' -MaxEvents 15 -ErrorAction SilentlyContinue | Format-Table -AutoSize -Wrap TimeCreated,Id,LevelDisplayName,Message
"=== volumes"; Get-Volume | Where-Object DriveLetter | Format-Table -AutoSize DriveLetter,FileSystemLabel,FileSystem,@{n="SizeGB";e={[math]::Round($_.Size/1GB,2)}},@{n="FreeGB";e={[math]::Round($_.SizeRemaining/1GB,2)}}
