# Tablet clone: try a startup-password protector with the slates setting AS DELIVERED by Fleet (no change to it). Random password,
# never shown, removed again. EnableBDEWithNoTPM is set to 1 locally first (the clone has no usable TPM).
Add-Type -Namespace W -Name P -MemberDefinition '[DllImport("powrprof.dll")] public static extern int PowerDeterminePlatformRoleEx(uint v);'
$k = Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\FVE
"time: " + (Get-Date -Format s) + "  PlatformRole: " + [W.P]::PowerDeterminePlatformRoleEx(2) + "  OSEnablePrebootInputProtectorsOnSlates=" + $k.OSEnablePrebootInputProtectorsOnSlates + "  EnableBDEWithNoTPM=" + $k.EnableBDEWithNoTPM
$rng=[System.Security.Cryptography.RandomNumberGenerator]::Create(); $b=New-Object byte[] 12; $rng.GetBytes($b)
$p = ConvertTo-SecureString ("Lab-" + [Convert]::ToBase64String($b)) -AsPlainText -Force
try { Add-BitLockerKeyProtector -MountPoint C: -PasswordProtector -Password $p -ErrorAction Stop | Out-Null; "Add -PasswordProtector: OK" }
catch { "Add -PasswordProtector FAILED: 0x{0:X8} {1}" -f $_.Exception.HResult, ($_.Exception.Message -replace '\s+',' ') }
foreach ($x in (Get-BitLockerVolume -MountPoint C:).KeyProtector | Where-Object KeyProtectorType -eq Password) { Remove-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $x.KeyProtectorId | Out-Null; "(removed the test password protector again)" }
