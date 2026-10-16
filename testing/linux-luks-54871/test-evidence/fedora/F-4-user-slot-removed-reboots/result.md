# F-4: remove the user's key slot; does every reboot ask for the key? (Fedora)

- **Date:** 2026-10-16
- **Objective:** Q1: after the end user's LUKS key is removed, does the user have to contact IT at every reboot?
- **Expected:** The old passphrase is rejected, the escrowed key unlocks the disk, and every boot waits at the unlock prompt until someone types the key.

## Steps and evidence
- `01`–`03`: masked luksDump before and after `luksKillSlot` on slot 0 (authorised with the escrow key).
- `04-checks-before-reboot.txt`: the old passphrase no longer opens any slot, the escrow key does, the data hash, Fleet's status.
- `05-reboot-1.txt`, `05-reboot-2.txt`: two cold restarts. SSH answered only after the watcher had typed the escrow key (about 90 s after the VM started), so the machine did not boot unattended. Both boots came up with only slot 1 and the same data hash.
- `06-fleet-after.txt`: Fleet's status afterwards (it does not check the user's slot).
- No screenshot of the unlock prompt: the Fedora console stays blank in this VM (see F-1). The Ubuntu run shows the prompt (K-3).

## Result: PASS
