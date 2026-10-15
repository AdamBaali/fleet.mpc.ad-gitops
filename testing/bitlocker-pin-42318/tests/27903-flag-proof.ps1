# fleetdm/fleet#27903: call Win32_EncryptableVolume the way fleetd 1.61.0 does (PrepareVolume, recovery password, Encrypt)
# on a decrypted data volume F:, first with flags 0x2 (fleetd's EncryptDemandWipe), then 0 (full mode per Microsoft).
# Prints return codes and protector IDs only, never the recovery password.
(Get-Date -Format o)
$v = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftVolumeEncryption -ClassName Win32_EncryptableVolume -Filter "DriveLetter='F:'"
$r = Invoke-CimMethod -InputObject $v -MethodName PrepareVolume -Arguments @{DiscoveryVolumeType="<default>"; ForceEncryptionType=[uint32]1}
"PrepareVolume(<default>, software) rc: 0x{0:X8}" -f $r.ReturnValue
$r = Invoke-CimMethod -InputObject $v -MethodName ProtectKeyWithNumericalPassword
"ProtectKeyWithNumericalPassword rc: 0x{0:X8}" -f $r.ReturnValue
$r = Invoke-CimMethod -InputObject $v -MethodName Encrypt -Arguments @{EncryptionMethod=[uint32]7; EncryptionFlags=[uint32]2}
"Encrypt(XTS-AES 256, flags 0x2 = fleetd EncryptDemandWipe) rc: 0x{0:X8}" -f $r.ReturnValue
(manage-bde -status F: | Select-String "Conversion Status|Percentage") -join " ; "
$r = Invoke-CimMethod -InputObject $v -MethodName Encrypt -Arguments @{EncryptionMethod=[uint32]7; EncryptionFlags=[uint32]0}
"Encrypt(XTS-AES 256, flags 0 = full mode per Microsoft) rc: 0x{0:X8}" -f $r.ReturnValue
Start-Sleep 20
manage-bde -status F: | Select-Object -Skip 3
"=== System BitLocker-Driver events for F: since start"
Get-WinEvent -FilterHashtable @{LogName="System"; StartTime=(Get-Date).AddMinutes(-2)} -ErrorAction SilentlyContinue | Where-Object ProviderName -match "BitLocker" | Sort-Object TimeCreated | ForEach-Object { "{0:HH:mm:ss} {1} {2}" -f $_.TimeCreated,$_.Id,($_.Message -replace "\s+"," ") }
