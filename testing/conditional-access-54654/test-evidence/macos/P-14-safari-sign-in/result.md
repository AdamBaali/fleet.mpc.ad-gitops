# macOS P-14: Safari sign-in with the lab certificate
- **Date:** 2026-10-08 (UTC), renewed certificate `F7313E7E...`, Safari opened fresh (it was not running).
- **What happened:**
  1. Safari shows its own picker "The website ping.lab requires a client certificate" with the host-UUID certificate selected (`01-safari-after-open.png`). Safari has no auto-select policy, so the picker always appears.
  2. After Continue, macOS asks "Safari wants to access key 'MDM Allow All' in your keychain" and wants the login keychain password (`02-keychain-prompt-screenshot-by-adam.png`, Adam's screenshot of the dialog).
  3. Adam chose **Deny**. Safari then shows "Safari Can't Open the Page ... can't establish a secure connection to the server ping.lab" at the port 9032 certificate step (`03-safari-after-deny.png`). No sign-in, as expected.
- **Finding:** even with `AllowAllAppsAccess` set in the profile, the first use of the key by each browser shows this prompt. The user has to enter the keychain password and choose Always Allow once per browser. The guide's macOS section should say so. This agrees with the earlier Chrome and Firefox runs.

## Result: PASS

After the user chose Always Allow on the keychain prompt, Safari signed in (`04-safari-after-allow.png`). Denying the prompt ends in "can't establish a secure connection".
