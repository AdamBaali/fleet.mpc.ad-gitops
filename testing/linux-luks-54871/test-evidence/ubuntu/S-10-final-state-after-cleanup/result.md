# S-10: final state of the lab VM after all tests

- **Date:** 2026-10-16
- **Objective:** Leave the VM in a known, healthy state and show Fleet agrees.
- **Expected:** User passphrase on one slot, Fleet's escrow key on another, nothing else, Fleet Verified.

## Steps and evidence
- `01-slots.txt`: slot 0 opens with the user's passphrase only; slot 2 (the newest escrow, created by orbit) opens with the key Fleet stores; a stale slot that neither key opened was removed. UUID and master key digest are the same as at the start (S-3).
- Fleet (checked after a refetch): `verified`, escrowed key available.

## Result: PASS
