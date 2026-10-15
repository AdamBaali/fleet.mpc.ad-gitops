# fleetdm/fleet#27903 test 3 check: volumes, BitLocker policy, MDM events for BitLocker, BitLocker events. No keys.
(Get-Date -Format o)
"=== volumes (no keys)"; Get-BitLockerVolume | Format-Table -AutoSize MountPoint,VolumeType,VolumeStatus,EncryptionPercentage,ProtectionStatus,@{n="Protectors";e={($_.KeyProtector.KeyProtectorType) -join "+"}} | Out-String -Width 200
"=== manage-bde conversion status"; foreach ($d in "C:","F:") { "$d " + ((manage-bde -status $d | Select-String "Conversion Status|Percentage Encrypted") -join " ;") }
"=== FVE policy"; reg query HKLM\SOFTWARE\Policies\Microsoft\FVE 2>&1 | Out-String
"=== PolicyManager current BitLocker"; reg query HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\BitLocker 2>&1 | Out-String
"=== MDM diagnostics (Admin) mentioning BitLocker or errors, last 15 min"
Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin"; StartTime=(Get-Date).AddMinutes(-15)} -ErrorAction SilentlyContinue | Where-Object { $_.Message -match "BitLocker|RequireDeviceEncryption|AllowWarning" -or $_.LevelDisplayName -eq "Error" } | Sort-Object TimeCreated | ForEach-Object { "{0:HH:mm:ss} {1} {2} {3}" -f $_.TimeCreated,$_.Id,$_.LevelDisplayName,($_.Message -replace "\s+"," ") }
"=== BitLocker Management events, last 15 min (no 811)"
Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-BitLocker/BitLocker Management"; StartTime=(Get-Date).AddMinutes(-15)} -ErrorAction SilentlyContinue | Where-Object Id -ne 811 | Sort-Object TimeCreated | ForEach-Object { "{0:HH:mm:ss} {1} {2} {3}" -f $_.TimeCreated,$_.Id,$_.LevelDisplayName,($_.Message -replace "\s+"," ") }
"=== BitLocker-API (BDE) events"; Get-WinEvent -ListLog *BitLocker* | Format-Table -AutoSize LogName,RecordCount | Out-String
