<!-- Comment for fleetdm/fleet#27903 (reply to spalmesano0, 2026-10-15). Adam posts. Open choice: file the fleetd
     full-encryption flag bug (T1) and the stale-key "Verified" gap (W) as separate issues. Evidence: EVIDENCE.md "Side request". -->
Thanks @spalmesano0. I tested this on Fleet 4.93.0 + fleetd 1.61.0 (Windows 11 Pro 26H2 VM with TPM 2.0, not Entra joined,
`enable_custom_disk_encryption` on, Fleet's disk encryption on):

- **Full encryption of C: doesn't work today, even with the right node.** `FixedDrivesEncryptionType` only covers fixed *data*
  drives; C: needs
  [`SystemDrivesEncryptionType`](https://learn.microsoft.com/en-us/windows/client-management/mdm/bitlocker-csp#systemdrivesencryptiontype)
  (`OSEncryptionTypeDropDown_Name` = 1). With that profile, fleetd reads the policy ("OSEncryptionType registry policy requires
  full disk encryption"), deletes it, and then fails: "the encryption flags conflict with the current Group Policy settings". Its
  retry 30 s later finds no policy and encrypts **used space only**. Fleet shows the disk and the profile as Verified.
  Cause: fleetd passes `0x2` for full mode
  ([`EncryptDemandWipe`](https://github.com/fleetdm/fleet/blob/orbit-v1.61.0/orbit/pkg/bitlocker/bitlocker_management_windows.go#L36-L38)).
  Microsoft defines `0x2` as an on-demand free-space wipe of an *already encrypted* volume; full mode is flags `0`. On a test
  volume, the same calls returned `E_INVALIDARG` with `0x2` and gave "Fully Encrypted" with `0`. This needs a fleetd fix.
- **What works now: `manage-bde -w C:` as a Fleet script.** On a used-space C: it returns at once and wipes the free space in the
  background ("Wiping of free space on volume C: completed", System event 24651). That covers the concern above (data deleted
  before BitLocker was turned on), on machines already in use and on new ones, with no custom profile. BitLocker stays on, and
  `manage-bde -status` still says "Used Space Only Encrypted" afterwards, so the event is the proof of the wipe.
- **Don't re-encrypt C: outside Fleet on hosts that already have a key in Fleet.** I decrypted C: and re-encrypted it in full
  mode with a script. Fleet kept showing Verified, but the escrowed recovery key no longer matched any protector on the drive.
- **All drives (the other request in the issue):** Fleet encrypts and escrows C: only. With `RequireDeviceEncryption` = 1 and
  `AllowWarningForOtherDiskEncryption` = 0, a second fixed drive stayed unencrypted. Windows' BitLocker MDM refresh task
  returned "not supported", and adding `AllowStandardUserEncryption` = 1 didn't change that. Fleet still showed the profiles as
  Verified. Microsoft says silent mode needs Entra-joined devices and backs data-drive keys up to AD, Entra or OneDrive, not to
  Fleet. So this needs Fleet to encrypt and escrow data drives.
- **Microsoft's note at the top of the page:** CSP management beyond `RequireDeviceEncryption` needs Windows Enterprise E3/E5 (or
  A3/A5) licences, and all BitLocker settings must be sent in a single SyncML, so one custom profile.
