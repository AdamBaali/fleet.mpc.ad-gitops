# Check of the ask against the evidence (fleetdm/fleet#54871)

Generated 2026-10-16 13:17 from the result files. Nothing here is posted anywhere.

## What was asked
Issue #54871 ("CSA task: Help clarify and document Linux/LUKS behavior"), from the discussion in #35241. Three things to document and verify:
1. "Removing end user LUKS key means they have to reach out to IT every time they reboot"
2. "LUKS doesn't invalidate any encryption key"
3. "Do we support key escrow in Arch Linux? If so, could we document that as well?"
For each: what Fleet does (docs and code), what a real Linux VM does, what a customer should know, a proposed doc edit.

## 1. Removing the end user's key means contacting IT on every reboot
| Question | Answer | Evidence |
| --- | --- | --- |
| What does Fleet do? | Escrow only **adds** a keyslot with a random passphrase. Nothing in Fleet removes or edits the end user's slot. Fleet verifies the escrow slot only, so it doesn't notice the user slot is gone. | [D-1-fleet-code-and-docs](test-evidence/desk/D-1-fleet-code-and-docs/): PASS, [K-7-fleet-after-user-slot-removed](test-evidence/ubuntu/K-7-fleet-after-user-slot-removed/): PASS |
| After removal, can the user unlock? | **No.** The old passphrase is rejected at the boot prompt ("No key available with this passphrase") and the disk asks again. | [K-3-reboot-old-passphrase-rejected](test-evidence/ubuntu/K-3-reboot-old-passphrase-rejected/): PASS, [K-1-remove-user-keyslot](test-evidence/ubuntu/K-1-remove-user-keyslot/): PASS |
| Can IT unlock? | **Yes**, with the escrowed key (Show disk encryption key): it opens slot 1 and boots the machine. | [K-4-reboot-with-escrow-key](test-evidence/ubuntu/K-4-reboot-with-escrow-key/): PASS, [S-7-escrowed-key-unlocks-slot1](test-evidence/ubuntu/S-7-escrowed-key-unlocks-slot1/): PASS |
| Every reboot? | **Yes** on a standard install: each boot stops at the unlock prompt (no TPM token, no keyfile). Nothing remembers the key. | [K-5-every-boot-asks-again](test-evidence/ubuntu/K-5-every-boot-asks-again/): PASS, [K-6-no-other-unlock-path](test-evidence/ubuntu/K-6-no-other-unlock-path/): PASS |
| Caveats for customers | Header backups bring the removed key back. Removing the escrow slot makes Fleet show action required. A TPM-backed layout would not be locked out. | [K-11-header-restore-brings-back-removed-slot](test-evidence/ubuntu/K-11-header-restore-brings-back-removed-slot/): PASS, [K-9-escrow-slot-removed-fleet-reaction](test-evidence/ubuntu/K-9-escrow-slot-removed-fleet-reaction/): PASS, [K-6-no-other-unlock-path](test-evidence/ubuntu/K-6-no-other-unlock-path/): PASS |
Status: **PASS / PASS / PASS**. The claim is true as stated for a passphrase-only disk.

## 2. LUKS doesn't invalidate any encryption key
| Question | Answer | Evidence |
| --- | --- | --- |
| Does Fleet's escrow change the master key? | No. UUID and master key digest are identical before and after. | [S-3-baseline-luksdump](test-evidence/ubuntu/S-3-baseline-luksdump/): PASS, [S-6-luksdump-after-escrow](test-evidence/ubuntu/S-6-luksdump-after-escrow/): PASS |
| Do add, change, remove keyslot change it? | No. Digest, UUID and a data hash stayed the same through add, change, kill and remove. Other slots keep working. | [M-2-keyslot-changes-keep-master-key](test-evidence/ubuntu/M-2-keyslot-changes-keep-master-key/): PASS |
| What does change it? | Only `cryptsetup reencrypt` or reformatting (control on a scratch device). | [M-5-control-reencrypt-changes-the-key](test-evidence/ubuntu/M-5-control-reencrypt-changes-the-key/): PASS |
Status: **PASS**. True as stated.

## 3. Key escrow on Arch Linux
| Question | Answer | Evidence |
| --- | --- | --- |
| Does Fleet support it? | **No.** Docs list Ubuntu, Kubuntu, Fedora. The server code also accepts Arch, Arch ARM, Manjaro, CachyOS and Omarchy, but open PR #55070 removes them: "No user could complete escrow on them". Omarchy issue #55069 lists why (Wayland dialog environment, no zenity or kdialog, lsblk mountpoints). | [D-1-fleet-code-and-docs](test-evidence/desk/D-1-fleet-code-and-docs/): PASS |
| Live Arch test? | **Not done**: no Arch arm64 VM was built. | [A-Arch-VM-escrow](test-evidence/desk/A-Arch-VM-escrow/): BLOCKED |
Status: **answered from code, docs and open PRs; not shown on a live Arch VM.**

## The parent request, #35241 (Linux lock: reboot option and LUKS crypto-lock)
The three questions above came from it. Its proposal also asks for things that are product features, not behaviours; here is what the lab can say about each.
| #35241 item | What the lab shows | Evidence |
| --- | --- | --- |
| Crypto-lock: remove the user's keyslot, keep IT's recovery key, reboot | Works by hand: user rejected, IT key boots it, every boot asks again. Fleet does not notice the removal (so a built-in action needs its own audit event). | [K-1-remove-user-keyslot](test-evidence/ubuntu/K-1-remove-user-keyslot/): PASS, [K-3-reboot-old-passphrase-rejected](test-evidence/ubuntu/K-3-reboot-old-passphrase-rejected/): PASS, [K-4-reboot-with-escrow-key](test-evidence/ubuntu/K-4-reboot-with-escrow-key/): PASS, [K-7-fleet-after-user-slot-removed](test-evidence/ubuntu/K-7-fleet-after-user-slot-removed/): PASS |
| Prevent decrypt-and-mount after the lock | A scratch disk with the user slot removed can't be decrypted or mounted without the escrow key; no plain text in the image. A saved header copy would restore the old key. | [K-13-mount-after-user-key-removed](test-evidence/ubuntu/K-13-mount-after-user-key-removed/): PASS, [K-11-header-restore-brings-back-removed-slot](test-evidence/ubuntu/K-11-header-restore-brings-back-removed-slot/): PASS |
| Lock behaviour on Linux (what the lock script relies on) | Fleet's `linux_lock.sh` kills the user's processes, runs `passwd -l`, writes /etc/nologin, and on Ubuntu with GDM schedules a reboot into text mode. It does not touch sshd or SSH keys. | [L-2-ssh-after-fleet-lock](test-evidence/ubuntu/L-2-ssh-after-fleet-lock/): PASS |
| Customer comment: users can still SSH into a locked machine | Ordinary users are refused (PAM account/nologin). **root is exempt from /etc/nologin and still logs in with a key.** | [L-1-ssh-before-lock](test-evidence/ubuntu/L-1-ssh-before-lock/): PASS, [L-2-ssh-after-fleet-lock](test-evidence/ubuntu/L-2-ssh-after-fleet-lock/): PASS |
| Unlock restores the machine | Yes (nologin gone, password unlocked, graphical target restored, user logs in). | [L-3-unlock-restores](test-evidence/ubuntu/L-3-unlock-restores/): PASS |
| "Lock and reboot for all" option, prerequisite policies, dry-run, audit events | Product features: not testable as behaviour. Noted for the product team. | none |

## Also required by the task
| Requirement | Status |
| --- | --- |
| Follow the end user guide word for word on a VM | Ubuntu desktop installer followed with screenshots ([S-1-installer](test-evidence/ubuntu/S-1-installer/): PASS). The main runs drove orbit's flow through the same API and a lab zenity wrapper ([S-4-escrow-trigger](test-evidence/ubuntu/S-4-escrow-trigger/): PASS); the real Fleet Desktop banner and passphrase dialog were captured separately ([G-banner-and-dialog](test-evidence/ubuntu/G-banner-and-dialog/): PASS). Deviations are logged. |
| `luksDump` before and after each step | Done, masked: [S-3-baseline-luksdump](test-evidence/ubuntu/S-3-baseline-luksdump/): PASS, [S-6-luksdump-after-escrow](test-evidence/ubuntu/S-6-luksdump-after-escrow/): PASS, [K-1-remove-user-keyslot](test-evidence/ubuntu/K-1-remove-user-keyslot/): PASS, [M-2-keyslot-changes-keep-master-key](test-evidence/ubuntu/M-2-keyslot-changes-keep-master-key/): PASS |
| Second distro (Fedora) | [F-Fedora-VM-repeat](test-evidence/desk/F-Fedora-VM-repeat/): NOT-RUN |
| Proposed doc edits in Fleet's style | [DOC_EDITS.md](DOC_EDITS.md) |
| Short issue update for Adam to paste | [ISSUE_UPDATE.md](ISSUE_UPDATE.md) (draft, never posted) |
| Evidence Adam can review | [EVIDENCE.md](EVIDENCE.md) |
| No secrets in evidence | Scanned: passphrases, keys and tokens are not in the folder. Header backups stay in the guest. |

## Open
- Arch VM and Fedora VM were not built. Ubuntu 26 TPM-backed FDE (snapd) is a different path and was not tested.
- Nothing is pushed or posted.

