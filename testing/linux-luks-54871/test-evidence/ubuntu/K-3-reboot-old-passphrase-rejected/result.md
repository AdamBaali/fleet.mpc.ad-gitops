# K-1 / K-3: remove the end user's key, then reboot: the old passphrase is rejected

- **Date:** 2026-10-15
- **Objective:** Q1: after IT removes the end user's LUKS key, what happens at boot?
- **Expected:** The user's passphrase no longer unlocks the disk. Only the escrowed key does.

## Steps and evidence
- `01-remove-user-slot-again.txt`: `cryptsetup luksKillSlot /dev/nvme0n1p3 0` authorised with the escrowed key (the way a "crypto-lock" would be done). Slot 0 removed, slot 1 (escrow) left.
- `02-unlock-prompt-after-old-passphrase-typed.png`: the boot console after a cold restart. The user's old passphrase was typed (by `tools/unlock-watch.sh`): **"No key available with this passphrase. cryptsetup: ERROR: dm_crypt-0: cryptsetup failed, bad password or options?"**, then **"Please unlock disk dm_crypt-0:"** again. The disk stays locked; the guest never comes up (no network address, `03-guest-reachable.txt`).
- Earlier, without a reboot (K-1, `../K-1-remove-user-keyslot/`): the user passphrase is rejected on every slot, the escrowed key opens slot 1, the root file system stays mounted and the data hash is unchanged.

## Result: PASS

Answer to Q1 so far: yes, after the end user's key slot is removed, the end user can't unlock the disk, and the prompt just asks again. Whether they must contact IT on **every** reboot is K-4/K-5 (escrow key boots it; does the next boot ask again?).
