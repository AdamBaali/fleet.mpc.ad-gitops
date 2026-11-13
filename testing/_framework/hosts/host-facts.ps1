# Facts about a Windows test host, for the first evidence item of a test. Read-only.
# Run it through qga.sh (VM guest agent, as SYSTEM), a Fleet script, or an admin PowerShell.
# It prints no IP addresses, user names, or serial numbers: the repo is public.
# Not yet run on a host from this framework: check the output once before relying on it.
$ErrorActionPreference = 'Continue'
$os = Get-CimInstance Win32_OperatingSystem
"utc_now        {0:yyyy-MM-ddTHH:mm:ssZ}" -f (Get-Date).ToUniversalTime()
"os             $($os.Caption) $($os.Version) build $($os.BuildNumber) $($env:PROCESSOR_ARCHITECTURE)"
"virt           $((Get-CimInstance Win32_ComputerSystem).Model)"
"memory_mb      $([int]($os.TotalVisibleMemorySize / 1024))"
"disk_free_gb   $([int]((Get-PSDrive C).Free / 1GB))"
$tpm = Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue
"tpm            $(if ($tpm) { "present, enabled=$($tpm.IsEnabled_InitialValue)" } else { 'none' })"
"bitlocker_c    $((Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue).ProtectionStatus)"
$orbit = 'C:\Program Files\Orbit\bin\orbit\orbit.exe'
"orbit          $(if (Test-Path $orbit) { (Get-Item $orbit).VersionInfo.ProductVersion } else { 'not found at default path' })"
"orbit_service  $((Get-Service -Name 'Fleet osquery' -ErrorAction SilentlyContinue).Status)"
"mdm_enrolled   $([bool](Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue | Where-Object { $_.GetValue('ProviderID') }))"
"time_service   $((Get-Service w32time -ErrorAction SilentlyContinue).Status)"
