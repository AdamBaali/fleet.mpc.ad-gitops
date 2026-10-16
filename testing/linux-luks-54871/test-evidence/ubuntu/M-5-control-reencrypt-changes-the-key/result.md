# M-5: control, what DOES change the volume key

- **Date:** 2026-10-15
- **Objective:** Show the test can detect a key change, so "unchanged" above means something.
- **Expected:** `luksAddKey` and `luksKillSlot` keep the digest. `reencrypt` and `luksFormat` change it.

## Steps and evidence
- `01-control.txt` (`tests/q2-control-guest.sh`): a 64 MB scratch loop file, never the root device. Digest after `luksFormat` `04ac...`, after `luksAddKey` and `luksKillSlot` still `04ac...`, after `cryptsetup reencrypt` `8d04...`, after another `luksFormat` `e77a...`.
- The first attempt (inside `M-2`'s run) failed at reencrypt because the device had two keyslots and no `--key-slot`; rerun here with `--key-slot 0`.
- `02-screenshot-control.png`: window screenshot of the control run.

## Result: PASS
