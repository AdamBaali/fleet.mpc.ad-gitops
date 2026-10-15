# Tablet clone (no usable TPM): does Windows refuse a pre-boot keyboard protector (startup password) on a slate, and does
# OSEnablePrebootInputProtectorsOnSlates (profile D's setting) change that? Random password, never shown; removed afterwards.
param()
$k='HKLM:\SOFTWARE\Policies\Microsoft\FVE'
Set-ItemProperty $k -Name EnableBDEWithNoTPM -Value 1 -Type DWord   # allow startup without TPM (password / USB)
Add-Type -Namespace W -Name P -MemberDefinition '[DllImport("powrprof.dll")] public static extern int PowerDeterminePlatformRoleEx(uint v);'
"time: " + (Get-Date -Format s) + "  PlatformRole: " + [W.P]::PowerDeterminePlatformRoleEx(2) + "  OSEnablePrebootInputProtectorsOnSlates=" + (Get-ItemProperty $k).OSEnablePrebootInputProtectorsOnSlates
function TryAdd {
  $rng=[System.Security.Cryptography.RandomNumberGenerator]::Create(); $b=New-Object byte[] 12; $rng.GetBytes($b)
  $p = ConvertTo-SecureString ("Lab-" + [Convert]::ToBase64String($b)) -AsPlainText -Force
  try { Add-BitLockerKeyProtector -MountPoint C: -PasswordProtector -Password $p -ErrorAction Stop | Out-Null; "Add -PasswordProtector: OK" }
  catch { "Add -PasswordProtector FAILED: 0x{0:X8} {1}" -f $_.Exception.HResult, ($_.Exception.Message -replace '\s+',' ') }
  $pw = (Get-BitLockerVolume -MountPoint C:).KeyProtector | Where-Object KeyProtectorType -eq Password
  foreach ($x in $pw) { Remove-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $x.KeyProtectorId | Out-Null; "  (removed the test password protector again)" }
}
"== 1. slates setting not set"; Remove-ItemProperty $k -Name OSEnablePrebootInputProtectorsOnSlates -ErrorAction SilentlyContinue; TryAdd
"== 2. OSEnablePrebootInputProtectorsOnSlates = 1"; Set-ItemProperty $k -Name OSEnablePrebootInputProtectorsOnSlates -Value 1 -Type DWord; TryAdd
"== 3. back to not set"; Remove-ItemProperty $k -Name OSEnablePrebootInputProtectorsOnSlates -ErrorAction SilentlyContinue; TryAdd
"protectors: " + ((Get-BitLockerVolume -MountPoint C:).KeyProtector.KeyProtectorType -join ',')
