# K-5: does every reboot ask for the key again?

- **Date:** 2026-10-16
- **Objective:** Q1 claim: 'removing the end user's LUKS key means they have to reach out to IT every time they reboot'.
- **Expected:** Yes: nothing remembers the key, so each boot stops at the unlock prompt.

## Steps and evidence
- No prompt screenshot here: the script was started from a Terminal without screen-recording permission, so it could not capture the screen. The unlock prompt and the rejected passphrase are shown in `../K-3-reboot-old-passphrase-rejected/02-unlock-prompt-after-old-passphrase-typed.png`.
- `02-after-unlock.txt`: unlocked again only after the escrowed key was typed.
- `03-screenshot-second-reboot.png`: window screenshot of the second restart and the post-unlock checks.

## Result: PASS

Yes: with no TPM token (K-6) and no keyfile, **every** boot waits for a key that only IT has. The prompt is on the console, so it also blocks unattended reboots (updates, power loss).
