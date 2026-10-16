# F-2: Fleet escrow adds a key slot on Fedora

- **Date:** 2026-10-16
- **Objective:** Does Fleet's Linux escrow work on Fedora, and what does it change on the disk?
- **Expected:** One new key slot (slot 1) that the escrowed key opens; the user's slot 0 untouched; Fleet shows Verified.

## Steps and evidence
- The escrow was requested through Fleet's device API (`POST /device/{token}/mdm/linux/trigger_escrow`, HTTP 204); the passphrase dialog was answered by the lab zenity wrapper (as on Ubuntu). Orbit added the slot about 14 minutes later (this Mac was busy; Ubuntu took 4).
- `01-slots.txt`: Fleet status, slot list, which key opens which slot.
- `02-luksdump-masked.txt`: header after escrow (2 slots, salts masked).
- Before the request the disk had 1 slot (counted, not saved as a dump).

## Result: PASS

Note: the first run of this check printed FAIL because the script compared padded `wc -l` output (a test-script bug); the evidence file was correct and the verdict is recomputed from it.
