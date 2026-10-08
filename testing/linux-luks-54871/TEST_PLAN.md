# Test plan: fleetdm/fleet#54871 (Linux and LUKS)

Method: `_framework/README.md` (copied from the #54654 lab). One folder per test in `test-evidence/<group>/<ID>-<slug>/`,
raw output plus window-only pictures, secrets masked, a verdict per test, failures recorded before fixing.

Guides under test: `articles/linux-disk-encryption-end-user.md` and `articles/enforce-disk-encryption.md`
(sections "Escrow disk encryption key on Linux", "Encryption key changes", the Linux "Lock" and "Wipe" parts).
Questions from the issue: Q1 end user key removal, Q2 LUKS and keys, Q3 Arch. Background: #35241.

## Rule for every VM: follow the end user guide, don't shortcut it
The guide is for an end user, so the lab VM is installed the way an end user does it. No autoinstall seeds, no
pre-baked passphrase.
1. Ubuntu: installer ISO, **Use LVM with encryption**, passphrase chosen at the installer (word for word, step 1).
2. Fedora: installer, **Installation destination > Encryption > Encrypt my data**, passphrase chosen at the installer.
3. Verify with the guide's `lsblk` command (step 2).
4. Enroll fleetd (package built for the "Linux LUKS Lab" fleet), open Fleet Desktop, **Create key**, enter the
   passphrase (step 3). Wait for **Verified**.
Anything the guide doesn't say and I had to guess is logged as a deviation (`NOTES.md`) and may become a doc edit.

## Already checked desk-side (docs and code, see RESULTS.md)
- Escrow ADDS a keyslot (random 35-char passphrase). Nothing in orbit removes or edits the user's slot.
- Server accepts `ubuntu`, `zorin`, Fedora, `arch`, `archarm`, `manjaro`, `manjaro-arm`, `cachyos`, `omarchy`
  (`IsLUKSSupported`). Docs list Ubuntu, Kubuntu, Fedora only.
- Fleet verifies the escrowed key by reading the key slot number and salt from the LUKS header with osquery
  (`cryptsetup_luks_salt`) and comparing it with what was escrowed. Nothing there needs the user's slot.
- Orbit needs `cryptsetup` and `zenity` or `kdialog`, finds the root device with `lsblk`, assumes
  `aes-xts-plain64`.

## Setup (end user flow)
| ID | Test | Expected |
| --- | --- | --- |
| S-1 | Ubuntu 24.04 desktop installer, LVM with encryption, user picks passphrase | Encrypted install |
| S-2 | Guide step 2 `lsblk` command | Shows a `crypt` device, root marked encrypted |
| S-3 | Baseline `cryptsetup luksDump` (masked): version, UUID, keyslots, tokens, MK digest, segments | One slot, LUKS2 |
| S-4 | Install fleetd, host appears in the Linux LUKS Lab fleet, Fleet Desktop shows the escrow banner | Banner "Create key" |
| S-5 | Create key (step 3), wait | Status **Verified**, no banner |
| S-6 | `luksDump` after escrow | Two slots, same MK digest and UUID as S-3 |
| S-7 | Fleet **Show disk encryption key** | A key is shown (masked in pictures). It unlocks the volume: `cryptsetup open --test-passphrase` |
| S-8 | Reboot | User passphrase still unlocks. Boot unchanged |
| S-9 | Disk encryption table in Fleet | Host listed as Verified |

## Q1: remove the end user's key, then reboot
| ID | Test | Expected |
| --- | --- | --- |
| K-1 | Remove the user's slot with the escrowed key: `cryptsetup luksKillSlot <slot>` (key from a file, never typed in a command line) | Slot gone, one slot left |
| K-2 | `luksDump` after | The escrow slot only. MK digest and UUID unchanged |
| K-3 | Reboot. Try the user's old passphrase | Rejected ("No key available with this passphrase") |
| K-4 | Reboot. Enter the escrowed key | Unlocks and boots |
| K-5 | Reboot again, without IT intervention | Prompt again, every boot. Confirms "user has to contact IT every time" |
| K-6 | Is there any way the user stays unlocked (TPM token, keyfile in `/etc/crypttab`, `/boot` keyfile, snapd FDE)? Inspect tokens and crypttab on the VM | None on a standard install. Note any |
| K-7 | What Fleet shows after K-1 (status, banner, key) | Still Verified, banner not shown (the check uses the escrow slot's salt) |
| K-8 | Wait for the next detail query, then check for a re-escrow prompt | No prompt, or note what appears |
| K-9 | Remove the ESCROW slot instead (negative control) | Fleet detects the salt mismatch, status changes, banner or re-escrow prompt. Record it |
| K-10 | Same K-1 to K-5 on Fedora | Same result. Note dracut differences |
| K-11 | Unlock with the escrowed key, then restore a header backup taken before K-1 (`luksHeaderBackup` then `luksHeaderRestore`) | The removed user slot works again. Shows removal is only as good as the header: record it, it matters for "lock" |
| K-12 | Remove the user slot while the system is running (no reboot), try `cryptsetup luksOpen --test-passphrase` and mount from a live USB | Same rejection. The mounted volume stays usable until reboot |

## Q2: does LUKS invalidate any encryption key
| ID | Test | Expected |
| --- | --- | --- |
| M-1 | Write a marker file and record its SHA-256 | Baseline |
| M-2 | `luksAddKey`, `luksChangeKey`, `luksKillSlot` one at a time, `luksDump` between each | Slots change. MK digest, UUID, cipher and segments are identical every time |
| M-3 | Marker file still reads and hashes the same after M-2 and a reboot | Identical hash. No re-encryption happened |
| M-4 | Does anything else invalidate a key? Fleet's escrow flow (S-5/S-6) | Other slots keep working |
| M-5 | Negative control: what DOES change the volume key. Run `cryptsetup reencrypt` on a SCRATCH loop device (never the root) and compare `luksDump` | MK digest changes. Only reencrypt or luksFormat do this |
| M-6 | `cryptsetup luksDump --dump-volume-key` is NOT used (prints the key). Use `--test-passphrase` and the MK digest | Policy followed |

## Q3: Arch Linux
| ID | Test | Expected |
| --- | --- | --- |
| A-1 | Is there an Arch image that runs on Apple Silicon in UTM (Arch Linux ARM, archboot aarch64)? Which one did the customer use? | Record |
| A-2 | Install with LUKS2 root (plain `cryptsetup` + `mkinitcpio` `encrypt`/`sd-encrypt`), both with and without LVM | Encrypted root |
| A-3 | Build the fleetd package (`pkg.tar.zst`, arm64), install, enroll | Host enrolls. Note the platform string (`arch`, `archarm`) |
| A-4 | Install `cryptsetup`, `zenity` (or `kdialog`), a desktop with Fleet Desktop | Prerequisites listed |
| A-5 | Banner, **Create key**, **Verified** | Works, or record exactly where it fails |
| A-6 | Root detection (`lsblk` parent walk) on plain LUKS, LVM on LUKS, LUKS on LVM | Finds the device or fails clearly |
| A-7 | Server side: Show disk encryption key, host details | Works for `arch` and `archarm` |
| A-8 | Other: Manjaro, CachyOS and Omarchy are accepted by the server. Not tested | NOT-RUN, listed in NOTES |

## Suspected guide issues to confirm
| Guide | Issue | Proposed edit |
| --- | --- | --- |
| Both | Arch (and Manjaro, CachyOS, Omarchy, Zorin) work on the server but docs list Ubuntu, Kubuntu, Fedora only | Update the list after A-tests |
| Escrow | Doesn't say removing the user's key means a passphrase at every boot, IT holds the only key | Add a "Remove the end user's key" section after K-tests |
| Escrow | Doesn't say adding, changing or removing keys leaves the volume key and data unchanged | Add a note after M-tests |
| End user guide | Says encryption can only be enabled at install. True for the installer path only | Check wording |
| End user guide | "No escrow on hosts with multiple user accounts": check what the code does | Confirm or fix |
| Both | Ubuntu 26 TPM-backed FDE uses a different (snapd) path | Out of scope, mention in NOTES |

## Done when
- Every test has a verdict, failures are findings, not hidden.
- The end user guide was followed start to finish on Ubuntu and Fedora, deviations logged.
- Doc edits drafted in Fleet's style, issue update drafted (not posted).
- `_framework/bin/build-evidence-index.py` produced `EVIDENCE.md`; teardown list in `HANDOFF.md`.
