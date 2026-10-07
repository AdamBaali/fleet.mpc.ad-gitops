# P-3: Linux certificate import into browser stores

- **Started:** 2026-10-07T18:07:36Z
- **Objective:** The device certificate ends up in every browser store on the host (Chrome/Chromium NSS, Firefox deb, Firefox snap, Chromium snap).
- **Expected:** The guide's script imports into all stores. Where it doesn't, record which.

## Steps and evidence
- `01-certificate.txt` (VM): `openssl x509 -in /opt/company/certificate.pem -noout -subject -issuer -serial -dates -ext extendedKeyUsage 2>&`
- `02-stores-reset.txt` (VM): `bash /tmp/resetstores.sh; echo '--- stores after reset:'; bash /tmp/liststores.sh`
- `03-original-script-run.txt` (VM): `/opt/company/import-original.sh 2>&1 | tail -6; echo '--- stores after the ORIGINAL (PR) script:'; bash /tmp/l`
- `04-stores-reset-again.txt` (VM): `bash /tmp/resetstores.sh; echo '--- stores after reset:'; bash /tmp/liststores.sh`
- `05-patched-script-run.txt` (VM): `/opt/company/import-patched.sh 2>&1 | tail -6; echo '--- stores after the FIXED script:'; bash /tmp/liststores`
- `06-patched-rerun.txt` (VM): `/opt/company/import-patched.sh >/dev/null 2>&1; echo '--- after a second run (renewal replaces, no duplicates)`
- `07-key-present.txt` (VM): `runuser -u lab -- certutil -K -d sql:/home/lab/.pki/nssdb 2>&1 | head -3; runuser -u lab -- certutil -L -d sql`

## Result: **PASS**

The fixed script imports into all four stores (Chrome NSS, deb Firefox, snap Firefox, snap Chromium) and a rerun leaves one certificate per store. The original PR script missed the deb Firefox profile (~/.config/mozilla/firefox) and the snap Chromium store: 2 of 4 stores. Guide fix: commit 4702723cce.

_Finished 2026-10-07T18:08:03Z_
