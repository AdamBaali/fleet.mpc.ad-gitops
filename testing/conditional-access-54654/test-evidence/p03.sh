. evidence/lib.sh
ev_init P-3 "Linux certificate import into browser stores" "The device certificate ends up in every browser store on the host (Chrome/Chromium NSS, Firefox deb, Firefox snap, Chromium snap)." "The guide's script imports into all stores. Where it doesn't, record which." >/dev/null
ev_vm P-3 certificate "openssl x509 -in /opt/company/certificate.pem -noout -subject -issuer -serial -dates -ext extendedKeyUsage 2>&1; echo; sha256sum /opt/company/import-original.sh /opt/company/import-patched.sh | cut -c1-16,65-" >/dev/null
ev_vm P-3 stores-reset "bash /tmp/resetstores.sh; echo '--- stores after reset:'; bash /tmp/liststores.sh" >/dev/null
ev_vm P-3 original-script-run "/opt/company/import-original.sh 2>&1 | tail -6; echo '--- stores after the ORIGINAL (PR) script:'; bash /tmp/liststores.sh" >/dev/null
ev_vm P-3 stores-reset-again "bash /tmp/resetstores.sh; echo '--- stores after reset:'; bash /tmp/liststores.sh" >/dev/null
ev_vm P-3 patched-script-run "/opt/company/import-patched.sh 2>&1 | tail -6; echo '--- stores after the FIXED script:'; bash /tmp/liststores.sh" >/dev/null
ev_vm P-3 patched-rerun "/opt/company/import-patched.sh >/dev/null 2>&1; echo '--- after a second run (renewal replaces, no duplicates):'; bash /tmp/liststores.sh" >/dev/null
ev_vm P-3 key-present "runuser -u lab -- certutil -K -d sql:/home/lab/.pki/nssdb 2>&1 | head -3; runuser -u lab -- certutil -L -d sql:/home/lab/.pki/nssdb | head -6" >/dev/null
