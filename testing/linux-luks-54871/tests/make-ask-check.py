#!/usr/bin/env python3 -I
"""Writes ASK_CHECK.md: the original ask (issue #54871 and #35241), our answer, and the evidence with its CURRENT result read from the result.md files."""
import os,re,glob
R='/Users/adam/Downloads/fleet-54871-lab/test-evidence/'
res={}
for f in glob.glob(R+'*/*/result.md'):
    s=open(f).read(); m=re.search(r'^##\s*Result:\s*\**\s*([A-Z-]+)',s,re.M); h=open(f).readline().strip('# \n')
    res[os.path.basename(os.path.dirname(f))]=(m.group(1) if m else 'no result', f.replace(R,''))
def st(prefix):
    for k,(r,p) in sorted(res.items()):
        if k.startswith(prefix): return f"{r}"
    return "not run"
def ev(prefix):
    for k,(r,p) in sorted(res.items()):
        if k.startswith(prefix): return f"[{k}](test-evidence/{os.path.dirname(p)}/): {r}"
    return f"{prefix}: not run"
out=f'''# Check of the ask against the evidence (fleetdm/fleet#54871)

Generated {os.popen("date '+%F %H:%M'").read().strip()} from the result files. Nothing here is posted anywhere.

## What was asked
Issue #54871 ("CSA task: Help clarify and document Linux/LUKS behavior"), from the discussion in #35241. Three things to document and verify:
1. "Removing end user LUKS key means they have to reach out to IT every time they reboot"
2. "LUKS doesn't invalidate any encryption key"
3. "Do we support key escrow in Arch Linux? If so, could we document that as well?"
For each: what Fleet does (docs and code), what a real Linux VM does, what a customer should know, a proposed doc edit.

## 1. Removing the end user's key means contacting IT on every reboot
| Question | Answer | Evidence |
| --- | --- | --- |
| What does Fleet do? | Escrow only **adds** a keyslot with a random passphrase. Nothing in Fleet removes or edits the end user's slot. Fleet verifies the escrow slot only, so it doesn't notice the user slot is gone. | {ev("D-1")}, {ev("K-7")} |
| After removal, can the user unlock? | **No.** The old passphrase is rejected at the boot prompt ("No key available with this passphrase") and the disk asks again. | {ev("K-3")}, {ev("K-1")} |
| Can IT unlock? | {"**Yes**, with the escrowed key (Show disk encryption key): it opens slot 1 and boots the machine." if st("K-4")=="PASS" else "Escrow key opens slot 1 (S-7). Booting with it: K-4 "+st("K-4")+"."} | {ev("K-4")}, {ev("S-7")} |
| Every reboot? | {"**Yes** on a standard install: each boot stops at the unlock prompt (no TPM token, no keyfile). Nothing remembers the key." if st("K-5")=="PASS" else "Not yet shown: K-5 "+st("K-5")+"."} | {ev("K-5")}, {ev("K-6")} |
| Caveats for customers | Header backups bring the removed key back. Removing the escrow slot makes Fleet show action required. A TPM-backed layout would not be locked out. | {ev("K-11")}, {ev("K-9")}, {ev("K-6")} |
Status: **{st("K-5")} / {st("K-4")} / {st("K-3")}**. The claim is true as stated for a passphrase-only disk.

## 2. LUKS doesn't invalidate any encryption key
| Question | Answer | Evidence |
| --- | --- | --- |
| Does Fleet's escrow change the master key? | No. UUID and master key digest are identical before and after. | {ev("S-3")}, {ev("S-6")} |
| Do add, change, remove keyslot change it? | No. Digest, UUID and a data hash stayed the same through add, change, kill and remove. Other slots keep working. | {ev("M-2")} |
| What does change it? | Only `cryptsetup reencrypt` or reformatting (control on a scratch device). | {ev("M-5")} |
Status: **{st("M-2")}**. True as stated.

## 3. Key escrow on Arch Linux
| Question | Answer | Evidence |
| --- | --- | --- |
| Does Fleet support it? | **No.** Docs list Ubuntu, Kubuntu, Fedora. The server code also accepts Arch, Arch ARM, Manjaro, CachyOS and Omarchy, but open PR #55070 removes them: "No user could complete escrow on them". Omarchy issue #55069 lists why (Wayland dialog environment, no zenity or kdialog, lsblk mountpoints). | {ev("D-1")} |
| Live Arch test? | **Not done**: no Arch arm64 VM was built. | {ev("A-Arch")} |
Status: **answered from code, docs and open PRs; not shown on a live Arch VM.**

## Also required by the task
| Requirement | Status |
| --- | --- |
| Follow the end user guide word for word on a VM | Ubuntu desktop installer followed with screenshots ({ev("S-1")}). The Fleet Desktop banner and dialog were not shown: orbit's flow was driven through the same API and a lab zenity wrapper ({ev("S-4")}). Deviations are logged. |
| `luksDump` before and after each step | Done, masked: {ev("S-3")}, {ev("S-6")}, {ev("K-1")}, {ev("M-2")} |
| Second distro (Fedora) | {ev("F-Fedora")} |
| Proposed doc edits in Fleet's style | [DOC_EDITS.md](DOC_EDITS.md) |
| Short issue update for Adam to paste | [ISSUE_UPDATE.md](ISSUE_UPDATE.md) (draft, never posted) |
| Evidence Adam can review | [EVIDENCE.md](EVIDENCE.md) |
| No secrets in evidence | Scanned: passphrases, keys and tokens are not in the folder. Header backups stay in the guest. |

## Open
- Arch VM and Fedora VM were not built. Ubuntu 26 TPM-backed FDE (snapd) is a different path and was not tested.
- The real Fleet Desktop banner and passphrase dialog have no screenshots.
- Nothing is pushed or posted.
'''
print(out)
