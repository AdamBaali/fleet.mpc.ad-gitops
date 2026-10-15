# Tablet clone only: try to add TPM+PIN with a random PIN (never shown), report the exact error. Mirrors tests/add-pin-random.ps1.
$ErrorActionPreference = 'Continue'
"time: " + (Get-Date -Format s)
$v = Get-BitLockerVolume -MountPoint C:
foreach ($kp in $v.KeyProtector | Where-Object { $_.KeyProtectorType -in 'Tpm','TpmPin','TpmPinStartupKey','TpmStartupKey' }) {
  Remove-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $kp.KeyProtectorId | Out-Null; "removed $($kp.KeyProtectorType)" }
"before add: " + ((Get-BitLockerVolume -MountPoint C:).KeyProtector.KeyProtectorType -join ',')
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create(); $b = New-Object byte[] 4
$d = -join (1..6 | ForEach-Object { $rng.GetBytes($b); [string]([BitConverter]::ToUInt32($b,0) % 10) })
$secure = ConvertTo-SecureString $d -AsPlainText -Force; Remove-Variable d
try { Add-BitLockerKeyProtector -MountPoint C: -TpmAndPinProtector -Pin $secure -ErrorAction Stop | Out-Null; "Add -TpmAndPinProtector: OK" }
catch { "Add -TpmAndPinProtector FAILED: 0x{0:X8} {1}" -f $_.Exception.HResult, $_.Exception.Message }
$wmi = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftVolumeEncryption -ClassName Win32_EncryptableVolume -Filter "DriveLetter='C:'"
$r = Invoke-CimMethod -InputObject $wmi -MethodName GetKeyProtectors -Arguments @{KeyProtectorType=[uint32]0}
"after: " + ((Get-BitLockerVolume -MountPoint C:).KeyProtector.KeyProtectorType -join ',')
"== manage-bde -protectors -add C: -TPMAndPIN (expect a prompt; stdin closed)"
cmd /c "echo.| manage-bde -protectors -add C: -TPMAndPIN 2>&1" | Select-Object -First 8
