# S-6: luksDump after the escrow

- **Date:** 2026-10-15
- **Objective:** What does Fleet's escrow change in the LUKS header?
- **Expected:** One new keyslot. UUID and master key digest unchanged.

## Steps and evidence
- `01-luksdump-after-escrow.txt`: keyslots 0 and 1 (both luks2, argon2id), still no tokens, one digest.
- UUID `22e0008a-...` and digest `76c786fef3c7172b...` are identical to the baseline (S-3).
- `02-screenshot-baseline-vs-after.png`: window screenshot: baseline and after-escrow `luksDump` side by side (same UUID, same digest, one more keyslot).

## Result: PASS

Escrow only adds a keyslot. The volume's master key (digest) did not change. First evidence for Q2.
