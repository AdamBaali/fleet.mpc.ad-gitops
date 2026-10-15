# K-1 and K-2: remove the end user's keyslot (no reboot)

- **Date:** 2026-10-15
- **Objective:** Remove slot 0 with the escrowed key and see what changes in the header and for each key.
- **Expected:** One slot left (the escrow one). UUID and digest unchanged. The running system is unaffected.

## Steps and evidence
- `01-kill-user-slot.txt`: header backup first (for K-11), then `cryptsetup luksKillSlot /dev/nvme0n1p3 0 --key-file <escrow key>`.
- `02-luksdump-after.txt`: only keyslot 1 remains; UUID and digest unchanged.
- `03-who-can-unlock-now.txt`: user passphrase rejected, escrow key opens, root still mounted, data hash unchanged.

## Result: PASS
