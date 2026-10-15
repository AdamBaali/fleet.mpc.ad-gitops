# Per-test check: policy as Windows sees it, MDM-delivered values, protectors (types only, never the recovery password).
"=== time"; Get-Date -Format o
"=== FVE policy (HKLM\SOFTWARE\Policies\Microsoft\FVE)"; reg query HKLM\SOFTWARE\Policies\Microsoft\FVE
"=== MDM PolicyManager BitLocker"; reg query HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\BitLocker 2>&1
"=== manage-bde -status C:"; manage-bde -status C:
"=== protector types (no keys)"; (Get-BitLockerVolume -MountPoint C:).KeyProtector | Format-Table -AutoSize KeyProtectorType,KeyProtectorId
"=== BitLocker-API events, last 15"; Get-WinEvent -LogName 'Microsoft-Windows-BitLocker/BitLocker Management' -MaxEvents 15 -ErrorAction SilentlyContinue | Format-Table -AutoSize -Wrap TimeCreated,Id,LevelDisplayName,Message
