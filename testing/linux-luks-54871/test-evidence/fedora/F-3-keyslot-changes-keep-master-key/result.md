# F-3: add, change, kill and remove key slots keep the master key (Fedora)

- **Date:** 2026-10-16
- **Objective:** Q2: does LUKS invalidate any encryption key when a passphrase or key slot is rotated?
- **Expected:** UUID, master key digest and the data hash stay the same through luksAddKey, luksChangeKey, luksKillSlot and luksRemoveKey. A scratch-device control shows that only `cryptsetup reencrypt` changes the digest.

## Steps and evidence
- `01-q2-run.txt`: raw output of `tests/q2-guest-any.sh` (digests shortened to 16 hex chars, no keys). Slot 2 is added, changed, killed, added again and removed, authorised with the escrow key. After every step the line shows UUID, digest, slot list and a hash of a marker file on the encrypted root.
- The control (M-5) runs on a 64 MB loop device, never on the root disk.
- `02-control-rerun.txt`: the control again with `--key-slot 0` on `cryptsetup reencrypt`. Digest unchanged after luksFormat, luksAddKey and luksKillSlot; changed after `reencrypt` and after a new `luksFormat`.

## Failure recorded first
In the first run the control step inside `01-q2-run.txt` printed "Key file ... can be used only with --key-slot or with exactly one key slot active" and reencrypt did not run, so the script's own verdict was FAIL. The Fedora copy of the script lacked `--key-slot 0`; it is fixed in `tests/q2-guest-any.sh` and the control was rerun on its own. The main M-1 to M-3 evidence was not affected.

## Result: PASS
