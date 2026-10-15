# Issue update for fleetdm/fleet#54871 (DRAFT for Adam to review and post. Never auto-posted.)

> Before posting: the reboot statements in point 1 depend on tests K-4 and K-5. Check `ASK_CHECK.md` shows PASS for both.
Tested on an Ubuntu 24.04.5 arm64 VM (LVM on LUKS2) enrolled in a lab fleet with Linux key escrow on. Evidence and doc edits are in `testing/linux-luks-54871` in my lab GitOps repo (`EVIDENCE.md`, `ASK_CHECK.md`, `DOC_EDITS.md`).

**1. Removing the end user's key.** Fleet only adds a keyslot (the escrow key). If you remove the end user's slot with the escrow key (`cryptsetup luksKillSlot`), the old passphrase is rejected at boot ("No key available with this passphrase") and the disk asks again. The escrowed key unlocks the host. Every boot then waits at the unlock prompt for the key, because nothing on a standard install remembers it (no TPM token, no key file). So yes: the end user can't boot, and neither can the host restart unattended. Fleet doesn't notice: status stays Verified. Removing Fleet's own slot makes Fleet show Action required (about 90 s after a refetch). A saved LUKS header can bring the removed key back. TPM-backed layouts aren't locked out.

**2. Does LUKS invalidate any key?** No. Fleet's escrow, `luksAddKey`, `luksChangeKey`, `luksKillSlot` and `luksRemoveKey` never changed the UUID or the master key digest, or the data (hash checked). Other slots kept working. Only `cryptsetup reencrypt` or reformatting changed the digest (checked on a scratch device).

**3. Arch Linux:** Not supported. Docs list Ubuntu, Kubuntu and Fedora. The server also accepts Arch, Manjaro, CachyOS and Omarchy, but fleetdm/fleet#55070 removes them because no user could complete escrow, and #55069 lists why for Omarchy. Not shown on a live Arch VM.

**Not done:** Fedora VM, a live Arch VM, and Ubuntu 26 TPM-backed FDE. The real Fleet Desktop banner and dialog weren't captured: the Create key request was sent through Fleet's device API and the passphrase dialog was answered by a lab wrapper (no one typed it). Escrow took about 4 minutes from request to key slot.
