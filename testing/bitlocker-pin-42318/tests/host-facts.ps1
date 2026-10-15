# S-1 / S-1b: what kind of host Windows thinks this is. Prints no keys.
"=== time"; Get-Date -Format o
"=== edition"; Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Format-List ProductName,EditionID,DisplayVersion,CurrentBuild,UBR
"=== Get-Tpm"; Get-Tpm | Format-List TpmPresent,TpmReady,TpmEnabled,TpmActivated,ManufacturerIdTxt,ManufacturerVersion
"=== Win32_Tpm"; Get-CimInstance -Namespace root\cimv2\security\microsofttpm -ClassName Win32_Tpm | Format-List SpecVersion,PhysicalPresenceVersionInfo
"=== Secure Boot"; try { Confirm-SecureBootUEFI } catch { "Confirm-SecureBootUEFI: $($_.Exception.Message)" }
"=== powercfg /a (Modern Standby shows as S0 Low Power Idle)"; powercfg /a
"=== form factor"; Get-CimInstance Win32_ComputerSystem | Format-List Manufacturer,Model,PCSystemType,PCSystemTypeEx
Get-CimInstance Win32_SystemEnclosure | Format-List ChassisTypes
"=== keyboards"; Get-PnpDevice -Class Keyboard -PresentOnly | Format-Table -AutoSize Status,FriendlyName,InstanceId
"=== WinRE"; reagentc /info
"=== manage-bde -status C:"; manage-bde -status C:
"=== protector types (no keys)"; (Get-BitLockerVolume -MountPoint C:).KeyProtector | Format-Table -AutoSize KeyProtectorType,KeyProtectorId
"=== FVE policy"; reg query HKLM\SOFTWARE\Policies\Microsoft\FVE
