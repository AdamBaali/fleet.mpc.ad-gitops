# P-11: No certificate: sign-in is denied

- **Started:** 2026-10-07T18:17:04Z
- **Objective:** A client that presents no certificate cannot sign in.
- **Expected:** error=access_denied and 'Authentication failed'.

## Steps and evidence
- `01-no-cert-signin.txt` (VM): `bash /tmp/signin.sh nocert`

## Result: **PASS**

Without a client certificate PingFederate redirects with error=access_denied and the message Authentication failed.

_Finished 2026-10-07T18:17:04Z_

### Browser screenshots added 2026-10-08: Chromium with no certificate-picking policy; the picker is dismissed with Cancel, so no certificate is sent.
- `02-browser-remove-autoselect-policy.txt` (VM): `mv /var/snap/chromium/current/policies/managed/fleet-autoselect.json /tmp/fleet-autoselect.json.keep; ls -la /`
- `03-browser-launch.txt` (VM): `bash /tmp/br.sh chromium`
- `04-browser-picker-shown.png` (VM screenshot)
- `05-browser-after-cancel.png` (VM screenshot)
- `06-browser-callback-log.txt` (VM): `bash /tmp/killbr.sh`
- `07-browser-restore-policy.txt` (VM): `mv /tmp/fleet-autoselect.json.keep /var/snap/chromium/current/policies/managed/fleet-autoselect.json; ls /var/`
