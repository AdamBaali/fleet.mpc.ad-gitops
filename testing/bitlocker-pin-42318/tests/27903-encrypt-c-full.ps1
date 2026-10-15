# fleetdm/fleet#27903 workaround: encrypt C: in FULL mode (Enable-BitLocker without -UsedSpaceOnly) with a TPM protector,
# before Fleet's disk encryption is turned on. fleetd then adds and escrows its own recovery password. Prints types only.
"start: " + (Get-Date -Format o)
$r = Enable-BitLocker -MountPoint C: -EncryptionMethod XtsAes256 -TpmProtector -SkipHardwareTest -ErrorAction Stop -WarningAction SilentlyContinue
"Enable-BitLocker: VolumeStatus $($r.VolumeStatus), protectors $(($r.KeyProtector.KeyProtectorType) -join '+')"
Start-Sleep 5
manage-bde -status C:
