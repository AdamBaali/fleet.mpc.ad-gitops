# K-9: negative control, remove the ESCROW slot instead

- **Date:** 2026-10-15
- **Objective:** Does Fleet notice when its own key slot is removed? (Customer report: fleetdm/fleet#52236, closed as fixed.)
- **Expected:** Fleet detects it, shows action required, and offers re-escrow.

## Steps and evidence
- `01-remove-escrow-slot.txt`: `luksKillSlot ... 1` with the user passphrase. The stored escrow key no longer opens anything.
- `02-fleet-status-polling.txt`: Fleet stayed `verified` for about 90 s after a refetch, then moved to **action_required** with the key no longer available.
- `03-re-escrow.txt`: `trigger_escrow` again: a new keyslot about 3.5 minutes later, Fleet back to **verified**, a new key stored that opens slot 1.
- `04-screenshot-fleet-polling.png`: window screenshot: Fleet verified, then action_required after the escrow slot is removed, then verified again after re-escrow.

## Result: PASS

Fleet detects a removed escrow slot (within about two minutes after a refetch). It does **not** detect a removed end user slot (K-7).
