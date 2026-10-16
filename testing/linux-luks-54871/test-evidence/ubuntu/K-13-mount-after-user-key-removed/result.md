# K-13: decrypt and mount after the end user's key is removed

- **Date:** 2026-10-16
- **Objective:** #35241 item 4: after a crypto-lock, can the disk be decrypted and mounted without IT's key (the 'decrypt-and-mount workaround')?
- **Expected:** No. Only the escrowed key opens and mounts it.

## Steps and evidence
- `01-k13.txt` (`tests/k13-mount-guest.sh`, a 96 MB scratch LUKS2 disk with a file, never the root device): the user's old passphrase is rejected ('No key available with this passphrase') after slot 0 is removed; mounting the raw device fails (it is crypto_LUKS); the escrow key opens and mounts it and the file hash matches; the encrypted image holds no plain text.

## Result: PASS

On a stolen or live-booted disk, removing the user's slot blocks decrypt-and-mount unless the attacker also has the escrowed key or an old header copy (K-11).
