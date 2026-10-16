# K-11: a header backup brings a removed key back

- **Date:** 2026-10-15
- **Objective:** How permanent is removing a keyslot?
- **Expected:** `luksHeaderRestore` from an earlier backup restores the removed slot.

## Steps and evidence
- `01-restore.txt`: header backup taken before slot 0 was removed; after `cryptsetup luksHeaderRestore` the user's passphrase unlocks the volume again (slots 0 and 1, same UUID and digest).
- `02-screenshot-restore.png`: window screenshot of the restore.

## Result: PASS

Doc point: a "crypto-lock" is only as strong as the absence of header backups. Anyone with a copy of the old header and the old passphrase can restore the old key. (Backups made by installers or backup tools count.)
