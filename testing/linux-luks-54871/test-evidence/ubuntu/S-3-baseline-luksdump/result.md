# S-3: baseline luksDump (before Fleet escrow)

- **Date:** 2026-10-15
- **Objective:** Record the LUKS header before any Fleet change.
- **Expected:** LUKS2, one keyslot (the end user's), no tokens.

## Steps and evidence
- `01-luksdump-baseline.txt`: `cryptsetup luksDump /dev/nvme0n1p3` from the guest. Salts masked, digest shortened.
- `02-lsblk-guide-step2.txt`: the guide's step 2 verify command: `crypto_LUKS` partition with `dm_crypt-0` and LVM.

## Result: PASS

LUKS version 2, UUID shown, cipher aes-xts-plain64, **one keyslot (0, argon2id)**, no tokens, one digest. This is the baseline for Q1 and Q2.
