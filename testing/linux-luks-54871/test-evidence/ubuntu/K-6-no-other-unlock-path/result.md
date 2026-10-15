# K-6: is there any other unlock path?

- **Date:** 2026-10-16
- **Objective:** Q1 customer idea: remove the user's key so they need IT. Check nothing else unlocks the disk (TPM token, keyfile, crypttab keyscript).
- **Expected:** None on a standard install.

## Steps and evidence
- `01-unlock-paths.txt`: crypttab, LUKS tokens, key files, initramfs scripts, TPM device, snapd FDE.

## Result: PARTIAL

On this installer's default LVM-and-encryption layout the passphrase is the only unlock method. A machine with a TPM token (systemd-cryptenroll, Ubuntu 26 snapd FDE) or a keyfile in crypttab would not be locked out by removing the passphrase slot.
