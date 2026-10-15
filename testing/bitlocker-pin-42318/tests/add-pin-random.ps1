# Fleet script (runs as SYSTEM via fleetd): add a BitLocker TPM+PIN protector to C: with a random 6-digit PIN that is never
# shown, logged or stored. Lab only (#42318 close-out): tests the "script" route from the issue without anyone typing a PIN.
# The PIN can't be recovered; the recovery password (escrowed in Fleet) is the only way back in if the PIN is ever needed.
$ErrorActionPreference = 'Stop'
"before: " + ((Get-BitLockerVolume -MountPoint C:).KeyProtector.KeyProtectorType -join ',')
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$b = New-Object byte[] 4
$digits = -join (1..6 | ForEach-Object { $rng.GetBytes($b); [string]([BitConverter]::ToUInt32($b, 0) % 10) })
$secure = ConvertTo-SecureString $digits -AsPlainText -Force
Remove-Variable digits
try {
    Add-BitLockerKeyProtector -MountPoint C: -TpmAndPinProtector -Pin $secure | Out-Null
    "Add-BitLockerKeyProtector -TpmAndPinProtector: OK"
} catch {
    "Add-BitLockerKeyProtector -TpmAndPinProtector FAILED: $($_.Exception.Message)"
    exit 1
}
$v = Get-BitLockerVolume -MountPoint C:
foreach ($kp in $v.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }) {
    Remove-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $kp.KeyProtectorId | Out-Null
    "removed TPM-only protector"
}
"after: " + ((Get-BitLockerVolume -MountPoint C:).KeyProtector.KeyProtectorType -join ',')
