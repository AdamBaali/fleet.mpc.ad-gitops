# S-5: Fleet's view after the escrow

- **Date:** 2026-10-15
- **Objective:** Does Fleet show the host as Verified and hold the key?
- **Expected:** Verified, key available, key stored.

## Steps and evidence
- `01-fleet-api-after-escrow.txt`: host in fleet 5, `os_settings.disk_encryption.status` = verified, fleet summary linux verified 1, an escrowed key is stored (length 35, `updated_at` at the escrow time). Key value not shown.

## Result: PASS
