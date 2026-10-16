# fleetdm/fleet#27903 "BitLocker: encrypt empty disk space (as well as all drives)" — research and lab tests (2026-10-15)

Sources: the issue and its comments (gh, read-only); Fleet repo at tag `orbit-v1.61.0` / `fleet-v4.93.0`; Microsoft BitLocker CSP
doc (updated 2025-11-06) and `Win32_EncryptableVolume.Encrypt` doc. **Tested** 15:13-17:20 on the #42318 lab: Fleet 4.93.0
(`FLEET_MDM_ENABLE_CUSTOM_DISK_ENCRYPTION=true`), fleet 7, fleetd 1.61.0, host 15 = UTM VM `bitlocker-lab` (Windows 11 Pro 26H2
build 26300 arm64, TPM 2.0, not Entra/AD joined, standard user signed in). Log: `RESULTS.md` ("Side tests for #27903"); evidence:
`test-evidence/27903/`.

## Two requests in one issue
1. **Author (opened 2025-04-04):** full encryption of the **OS drive (C:)** instead of used-space-only. Reason (2026-10-14): data
   deleted *before* BitLocker was turned on stays in free clusters as plaintext on already-deployed machines. They said they could
   "add additional scripting to wipe the free space" but wanted a feature.
2. **Another customer** (issue body): encrypt **all drives**, not just C:.

## Test results
| Test | Result | Evidence |
|---|---|---|
| T2: `manage-bde -w C:` as a Fleet script on a "Used Space Only Encrypted" C: | **PASS.** Script exits 0 in seconds ("Free space wiping is now in progress."); the wipe runs in the background; System event 24651 "Wiping of free space on volume C: completed." 22 s later (9 GB free). BitLocker stays on, same protectors. `manage-bde` still says **"Used Space Only Encrypted"** after the wipe: event 24651 is the proof, not the status. | `03`-`06` |
| T1: profile `SystemDrivesEncryptionType` = 1 + Fleet's disk encryption on, decrypted C: | **FAIL.** C: ends **"Used Space Only Encrypted"**. fleetd logs "OSEncryptionType registry policy requires full disk encryption", deletes the value, then "failed to encrypt the volume ... the encryption flags conflict with the current Group Policy settings"; its retry 30 s later (no log line) encrypts used-space only. Fleet: disk encryption **"verified"**, profile **"verified"**. | `10`-`14` |
| T1 cause: Encrypt flags on a decrypted data volume (same WMI calls as fleetd) | flags `0x2` (fleetd's `EncryptDemandWipe`) -> `0x80070057` E_INVALIDARG; flags `0` -> "Fully Encrypted". Microsoft: `0x2` = "on-demand wipe of the volume free space", only on an already encrypted volume; full mode = bit `0x1` not set. **fleetd bug** (`orbit/pkg/bitlocker/bitlocker_management_windows.go:38,459`). | `16` |
| T3: unencrypted fixed data drive + `RequireDeviceEncryption` 1 + `AllowWarningForOtherDiskEncryption` 0 (Fleet's disk encryption on) | **Drive NOT encrypted** (no silent encryption, no prompt). Windows' "BitLocker MDM policy Refresh" task: `0x80070032` (not supported); with `AllowStandardUserEncryption` 1 added, the task returns 0 but nothing encrypts (5+ min). MDM warning 2910 "BitLocker CSP: Fixed Drive not protected." No conflict with fleetd on C:. Fleet: all profiles **"verified"**. Entra-joined host not tested. | `17`-`24` |
| W: full mode by Fleet script (`Enable-BitLocker`, no `-UsedSpaceOnly`) with Fleet's disk encryption off, then on | Full mode **PASS** ("Fully Encrypted"). Escrow **not shown**: this host already had a key in Fleet, so Fleet never asked fleetd for a new one and showed "verified" for 11+ min with only a TPM protector on C: (the escrowed key no longer matched any protector). A host Fleet has never escrowed for would take fleetd's rotate-and-escrow path (code); not tested. | `25`-`29` |

Other observations: `Get-BitLockerVolume` reports `VolumeStatus FullyEncrypted` for Used Space Only volumes (only `manage-bde`
tells them apart); fleetd's deleted `OSEncryptionType` was **not** restored by the MDM (still absent 40 min later); Fleet doesn't
report full vs used-space.

## The comment (spalmesano0, 2026-10-15 12:15 UTC), checked
| Claim | Check | Verdict |
|---|---|---|
| "You can do this as of 4.90.0" with a custom BitLocker profile | 4.90 added `mdm.enable_custom_disk_encryption` (server option; Fleet-managed cloud needs Fleet to turn it on). Lab: 4.93.0 accepts BitLocker profiles with it on, also with Fleet's disk encryption on. | Profile is accepted, but see T1: full mode doesn't happen with fleetd 1.61.0 |
| Set `FixedDrivesEncryptionType` to 1 | That node is for **fixed data drives**. The OS drive's node is **`SystemDrivesEncryptionType`** (`OSEncryptionTypeDropDown_Name`, registry `OSEncryptionType`). | **Wrong node for C:**; the right node fails today (T1) |
| `RequireDeviceEncryption` = 1 for fixed data drives | Microsoft: silent only with `AllowWarningForOtherDiskEncryption` = 0, which "can only be set for Entra ID joined devices"; a data drive's key must back up to AD DS, Entra or OneDrive first. | **Didn't encrypt on a non-Entra host (T3)**; keys never go to Fleet |
| `FixedDrivesRequireEncryption` `<enabled/>` → unencrypted fixed drives read-only | Microsoft: "all fixed data drives that aren't BitLocker-protected will be mounted as read-only". | Correct per doc (not tested) |
| `RemovableDrivesRequireEncryption` → read-only; no way to enforce removable encryption | Matches the doc. | Correct per doc (not tested) |
| Note at the top of Microsoft's doc (screenshot) | Licensing: managing BitLocker through the CSP, except turning it on/off with `RequireDeviceEncryption`, needs Windows Enterprise E3/E5 or A3/A5 for the users. Also: "Settings are enforced only at the time encryption is started" and "You must send all the settings together in a single SyncML". | Worth stating |

## What Fleet does (code, checked against the tests)
- fleetd encrypts **C: only** (`orbit/pkg/bitlocker`), with recovery password + TPM, and escrows **that** key.
- Since **fleetd 1.54.0** (#41911) it reads `HKLM\SOFTWARE\Policies\Microsoft\FVE\OSEncryptionType` before encrypting and **deletes**
  it. Value `1` -> `EncryptDemandWipe` (`0x2`), which Windows rejects on a decrypted volume (T1); the retry then sees no value and
  uses `EncryptDataOnly`. So an MDM-delivered `OSEncryptionType` = 1 always ends in used-space encryption with fleetd 1.61.0. Fix:
  pass flags `0` for full mode, and don't delete the value before encryption has started.
- Fleet asks fleetd to encrypt/escrow only when the host isn't encrypted, has no decryptable key, or reported an error
  (`server/service/orbit.go:1170-1175`, 4.93.0). `bitlocker_key_protectors_verify` checks for a TPM-family protector and a PIN,
  not for a recovery password, so a key that no longer matches C: keeps "verified" (W).

## Answers (tested)
- **Request 1 (full encryption of C:):** `SystemDrivesEncryptionType` = 1 is the right node, but with Fleet's disk encryption on it
  doesn't work today (fleetd bug, T1). What works now on any Fleet-encrypted host, new or in use: `manage-bde -w C:` as a Fleet
  script (T2), which wipes the free space (the author's concern). The drive still reports "Used Space Only Encrypted".
- **Request 2 (all drives):** Fleet only encrypts and escrows C:. `RequireDeviceEncryption` didn't encrypt a data drive on a
  non-Entra host (T3), and on Entra hosts Microsoft sends the keys to Entra, not Fleet. Needs a Fleet feature (fleetd encrypting
  and escrowing data drives).
- Don't re-encrypt C: outside Fleet on a host that already has a key in Fleet (W): Fleet keeps a stale key and says "verified".

## Lab changes made for these tests (fleet 7 / VM)
C: shrunk 62.89 -> 36 GB and a 2 GB F: data partition added (to cap qcow2 growth; Mac was at 5.7 GB free until Adam deleted the
two broken VM bundles). Fleet 7 at the end: Windows disk encryption **on**, PIN required **off** (YAML baseline: PIN on), no
profiles. Profiles used: `profiles/E`, `F`, `G` (27903). Scripts: `tests/27903-*.ps1`.
