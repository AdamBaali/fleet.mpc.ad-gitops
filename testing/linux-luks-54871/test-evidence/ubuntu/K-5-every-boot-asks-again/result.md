# K-5: does every reboot ask for the key again?

- **Date:** 2026-10-16
- **Objective:** Q1 claim: 'removing the end user's LUKS key means they have to reach out to IT every time they reboot'.
- **Expected:** Yes: nothing remembers the key, so each boot stops at the unlock prompt.

## Steps and evidence
- `01-unlock-prompt-before-typing.png`: a second cold restart: the prompt appears again before anything is typed.
- `02-after-unlock.txt`: unlocked again only after the escrowed key was typed.

## Result: PASS

Yes: with no TPM token (K-6) and no keyfile, **every** boot waits for a key that only IT has. The prompt is on the console, so it also blocks unattended reboots (updates, power loss).
