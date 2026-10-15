# M-1 to M-3: key slot changes don't change the volume key or the data

- **Date:** 2026-10-15
- **Objective:** Q2: does adding, changing or removing a keyslot invalidate or change any encryption key?
- **Expected:** Slots change. UUID and master key digest are identical every time. The data is untouched.

## Steps and evidence
- `01-q2-run.txt` (script `tests/q2-guest.sh`, run in the guest): a random marker file is hashed first. Then `luksAddKey` (slot 2, authorised with the escrow key), `luksChangeKey` on slot 2, `luksKillSlot 2`, `luksAddKey` again and `luksRemoveKey`. After every step: UUID, shortened master key digest, slot list and marker hash.
- Result of every step: UUID `22e0008a-...`, digest `76c786fef3c7172b...`, marker hash `e65ed01544c8eb74` stayed the same. Only the slot list changed (`0 1` to `0 1 2` and back). After all of it the escrow key still opens slot 1 and the user passphrase still opens slot 0.
- The root file system stayed mounted on `/dev/mapper/ubuntu--vg-ubuntu--lv` throughout (no re-encryption).

## Result: PASS

Doc note: "LUKS doesn't invalidate any encryption key" is accurate for these operations: they only add, re-wrap or remove keyslots, and every other keyslot keeps working. The one thing that changes the volume key is `cryptsetup reencrypt` or reformatting (M-5).
