# K-12: recovering access after every known key was lost

- **Date:** 2026-10-16
- **Objective:** A test script deleted the only key file while the disk had one slot. Can access be recovered without any passphrase?
- **Expected:** Not from the running system's memory (root can't read the volume key); yes from an earlier header backup.

## Steps and evidence
- `01-recovery.txt`: (1) `dmsetup table --showkeys` shows only a kernel key reference (60 hex characters, not the 128 of a 64-byte key), so `luksAddKey --volume-key-file` fails: "Cannot read 64 bytes from keyfile". (2) `cryptsetup luksHeaderRestore` from the backup taken before the first slot removal brings back the user's slot. The user's passphrase opens the disk again; UUID and master key digest are unchanged; the root file system stayed mounted throughout.

## Result: PASS

Doc point: with a kernel that keeps the key in the keyring (cryptsetup 2.x default), an admin can't pull the volume key out of a running machine without a passphrase. The only way back in without any key is a copy of the old LUKS header, which restores the old keys: the same weakness as K-11. A lab lesson: never delete the only key file.
