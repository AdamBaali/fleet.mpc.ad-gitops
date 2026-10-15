# Fleet script (read-only): report how Windows classifies this device. "Slate" means BitLocker hides startup PIN/password
# unless SystemDrivesEnablePrebootInputProtectorsOnSlates is enabled (#42318 lab, reproduced 2026-10-16).
Add-Type -Namespace W -Name P -MemberDefinition '[DllImport("powrprof.dll")] public static extern int PowerDeterminePlatformRoleEx(uint v);'
$roles = 'Unspecified','Desktop','Mobile','Workstation','EnterpriseServer','SOHOServer','AppliancePC','PerformanceServer','Slate'
$r = [W.P]::PowerDeterminePlatformRoleEx(2)
$cs = Get-CimInstance Win32_ComputerSystem
"PlatformRole: $r ($($roles[$r]))"
"Model: $($cs.Manufacturer) $($cs.Model)"
"Slates setting (OSEnablePrebootInputProtectorsOnSlates): " + (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\FVE -ErrorAction SilentlyContinue).OSEnablePrebootInputProtectorsOnSlates
