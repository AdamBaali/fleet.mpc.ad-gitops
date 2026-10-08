# macOS D-5: Duo trusts the Mac (Trusted Endpoints)
- **Date:** 2026-10-08 (UTC), Chrome, Duo Desktop running, Mac listed in the macOS Trusted Endpoints integration by the sync loop.
- **Steps:** open the Duo Universal Prompt demo (`https://ping.lab:8443`), sign in as `lab-test`, approve the Duo prompt.
- **Result: PASS.** Duo returned the Auth Response. `access_device.device_info_source` is `duo_desktop`, so Duo identified the Mac through Duo Desktop and the Fleet-synced device record (`02-after-duo.png`). The IP address, location and one-time code are masked.
- Pictures: `01-demo-login-page.png`, `02-after-duo.png` (Chrome window only).
