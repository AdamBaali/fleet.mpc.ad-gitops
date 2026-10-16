# Issue update for fleetdm/fleet#54871 (DRAFT for Adam to review and post. Never auto-posted.)

> Before posting: push the GitOps repo so the evidence links work.
Tested on an Ubuntu 24.04 arm64 VM and repeated on a Fedora 44 arm64 VM (both LVM on LUKS2) with Linux key escrow on. Evidence: [EVIDENCE.md](https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/linux-luks-54871/EVIDENCE.md). Proposed doc edits: [DOC_EDITS.md](https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/linux-luks-54871/DOC_EDITS.md).

1. **Removing the end user's key:** Yes, the user has to ask IT at every boot. Fleet only adds a key slot. If the user's slot is removed, their passphrase is rejected at boot. The escrowed key unlocks the host. Nothing on a standard install remembers it (no TPM token or key file), so every reboot waits at the prompt. Fleet doesn't notice: status stays "Verified". Removing Fleet's own slot shows "Action required". A saved LUKS header can bring a removed key back.
2. **Does LUKS invalidate any key?** No. Escrow, `luksAddKey`, `luksChangeKey`, `luksKillSlot` and `luksRemoveKey` didn't change the UUID, the master key digest or the data. Only `cryptsetup reencrypt` or reformatting does.
3. **Arch Linux:** Not supported. The docs list Ubuntu, Kubuntu and Fedora. The server also accepts Arch, Manjaro, CachyOS and Omarchy, but #55070 removes them because no user could complete escrow. Not tested on a live Arch VM.

Also for #35241: with the user's slot removed, a disk can't be decrypted or mounted without the escrow key. Fleet's lock script refuses ordinary SSH logins, but root with an SSH key still gets in.

Docs gaps found: the passphrase dialog needs a visible, unlocked desktop (it times out after 60 s with no error in Fleet), and a request after a timeout returns 409 for several minutes. Escrow took about 4 minutes.

Fedora gave the same results for 1 and 2: escrow added key slot 1 and Fleet showed "Verified"; key slot changes kept the master key; with the user's slot removed, the old passphrase was rejected and each of two reboots waited for the escrowed key. Fleet's escrow worked there, but it took about 14 minutes in my lab (Ubuntu: about 4).

Not tested: a live Arch VM, TPM-backed layouts.
