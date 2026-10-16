# S-7: the escrowed key opens only its own slot

- **Date:** 2026-10-15
- **Objective:** Confirm the key Fleet stores is a separate slot from the end user's.
- **Expected:** Escrow key opens slot 1, not slot 0. User passphrase opens slot 0, not slot 1.

## Steps and evidence
- `01-which-slot-opens-with-which-key.txt`: `cryptsetup open --test-passphrase -S <slot>` for each pair.
- `02-screenshot-which-key-opens-what.png`: window screenshot of the slot and key matrix.

## Result: PASS

The key fetched from Fleet's API (**Show disk encryption key**) opens slot 1 only. The end user's slot 0 is independent. This is what makes removing slot 0 (Q1) leave IT with a working key.
