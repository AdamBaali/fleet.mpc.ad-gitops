# S-4: trigger Fleet's Linux escrow (the "Create key" action)

- **Date:** 2026-10-15
- **Objective:** Run the end user escrow flow without a person at the keyboard.
- **Expected:** Orbit asks for the passphrase, adds a keyslot, escrows the new key.

## Steps and evidence
- `01-trigger.txt`: `POST /api/latest/fleet/device/<token>/mdm/linux/trigger_escrow`, the call Fleet Desktop's **Create key** makes (token read in the guest, not shown). HTTP 204.
- `02-keyslot-count-polling.txt`: keyslot count went 1 to 2 about 4.5 minutes later (orbit picks the request up on its next config check).
- `03-orbit-log-dialogs.txt`: orbit's log: it runs `zenity --entry` (title "Enter disk encryption passphrase", `--hide-text`, 60 s timeout) as the logged-in user, then `zenity --info` "Disk encryption key escrowed to Fleet...".
- `04-screenshot-trigger-and-slots.png`: window screenshot: trigger, keyslot count 1 to 2, orbit running zenity.

## Result: PASS

**Deviation (no one typed the passphrase):** the guest has a lab wrapper `/usr/local/bin/zenity` that answers `--entry` with the lab passphrase from a root-managed file and passes every other call to the real `/usr/bin/zenity`. Orbit's own code, the passphrase validation, `luksAddKey` and the escrow call all ran unchanged; only the person typing is replaced. No dialog screenshot is claimed.
Timing finding: from "Create key" to a new keyslot took about 4.5 minutes here.
