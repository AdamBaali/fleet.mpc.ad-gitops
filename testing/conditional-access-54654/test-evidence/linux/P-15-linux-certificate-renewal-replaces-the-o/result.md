# P-15: Linux: certificate renewal replaces the old certificate

- **Started:** 2026-10-07T18:41:55Z
- **Objective:** A renewed certificate (new serial) is imported by rerunning the script; the old one is replaced, not duplicated; sign-in works with the new one. Fleet does not auto-renew Linux certificates.
- **Expected:** Exactly one 'Fleet device certificate' per store, with the new serial.

## Steps and evidence
- `01-before.txt` (VM): `echo 'file:'; openssl x509 -in /opt/company/certificate.pem -noout -serial -enddate; for d in /home/lab/.pki/n`
- `02-install-new-cert.txt` (VM): `cp -p /opt/company/certificate.pem /opt/company/certificate.pem.bak; cp -p /opt/company/CustomerUserNetworkAcc`
- `03-rerun-import-script.txt` (VM): `/opt/company/import-patched.sh 2>&1 | tail -2; echo 'after the rerun:'; for d in /home/lab/.pki/nssdb /home/la`
- `04-signin-with-new-cert.txt` (VM): `bash /tmp/signin.sh cert`

Fleet's renewal guide states automatic renewal is not supported for Linux, so a script (like the guide's EST/Hydrant step plus import-certificate-to-browsers.sh) has to fetch and import the new certificate. The macOS renewal is tracked separately in evidence/renewal.

## Result: **PASS**

Rerunning the import script after a new certificate was issued replaced the old one in every store (serial 6B49... to 333D...), one entry per store, and sign-in worked with the new certificate. Fleet does not renew Linux certificates automatically (its renewal docs), so the guide must tell people to fetch and import the new certificate themselves.

_Finished 2026-10-07T18:42:14Z_
