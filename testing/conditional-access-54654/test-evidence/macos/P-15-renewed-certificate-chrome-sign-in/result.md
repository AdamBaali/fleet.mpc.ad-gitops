# P-15 (macOS): sign-in works with the renewed certificate
- **Date:** 2026-10-08 (UTC)
- **Objective:** after Fleet renewed the lab certificate unattended (`F7313E7E...`, issued 05:38:40 UTC), Chrome still signs in without a prompt.
- **Result:** **PASS.** Chrome went straight to the callback with an authorization code (`callback ok`).
- Evidence: `01-chrome-callback-ok.png` (Chrome window only; the sign-in code and the profile area are masked), `02-certificate-and-callback.txt`.

## Result: PASS

Chrome signed in straight to the callback with the renewed certificate (see the picture).
