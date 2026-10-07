# P-4: Linux: users added later and Firefox profiles created later

- **Started:** 2026-10-07T18:08:03Z
- **Objective:** A user created after the import, or a Firefox profile created after it, does not get the certificate until the script runs again.
- **Expected:** Confirm, so the guide can tell people to rerun the script.

## Steps and evidence
- `01-create-user.txt` (VM): `id labx >/dev/null 2>&1 && userdel -r labx 2>/dev/null; useradd -m -s /bin/bash labx; ls -a /home/labx | head `
- `02-run-script.txt` (VM): `/opt/company/import-patched.sh 2>&1 | tail -3; echo '--- stores for labx after the script:'; bash /tmp/liststo`
- `03-firefox-profile-created-later.txt` (VM): `runuser -u labx -- mkdir -p /home/labx/.mozilla/firefox/lab01.default && runuser -u labx -- certutil -N -d sql`
- `04-cleanup.txt` (VM): `userdel -r labx 2>&1; id labx 2>&1 | head -1`

## Result: **PASS**

Confirmed: a user created later only gets the Chrome store when the script runs, and a Firefox profile created after the import stays empty until the script is run again. Guide note added (rerun after Firefox first opens and for new users).

_Finished 2026-10-07T18:08:23Z_
