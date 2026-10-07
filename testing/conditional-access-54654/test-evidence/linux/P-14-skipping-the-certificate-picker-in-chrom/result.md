# P-14: Skipping the certificate picker in Chromium and Firefox on Linux

- **Started:** 2026-10-07T18:34:21Z
- **Objective:** Chromium and Firefox show a certificate picker by default; the documented policies make them pick the Fleet certificate automatically.
- **Expected:** Picker without a policy; no picker with the right policy; picker still shown if the policy names the wrong port (9031).

## Steps and evidence
- `01-lab-prerequisite-trust-root.txt` (VM): `certutil -A -d sql:/home/lab/snap/chromium/current/.pki/nssdb -n FleetLabCAroot -t CT,, -i /opt/company/step-c`
- `02-chromium-policy-none.txt` (VM): `mkdir -p /var/snap/chromium/current/policies/managed; mv /var/snap/chromium/current/policies/managed/lab-autos`
- `03-chromium-no-policy-launch.txt` (VM): `bash /tmp/br.sh chromium`
- `04-chromium-no-policy.png` (VM screenshot)
- `05-chromium-no-policy-callback-log.txt` (VM): `bash /tmp/killbr.sh`
- `06-chromium-policy-wrong-port.txt` (VM): `cat > /var/snap/chromium/current/policies/managed/fleet-autoselect.json <<'EOF'
{"AutoSelectCertificateForUrls": ["{\"pattern\":\"https://ping.lab:9031\",\"filter\":{\"ISSUER\":{\"CN\":\"Fle
EOF
cat /var/snap/chromium/current/policies/managed/fleet-autoselect.json`
- `07-chromium-policy-port-9031-launch.txt` (VM): `bash /tmp/br.sh chromium`
- `08-chromium-policy-port-9031.png` (VM screenshot)
- `09-chromium-policy-port-9031-callback-log.txt` (VM): `bash /tmp/killbr.sh`
- `10-chromium-policy-right-port.txt` (VM): `cat > /var/snap/chromium/current/policies/managed/fleet-autoselect.json <<'EOF'
{"AutoSelectCertificateForUrls": ["{\"pattern\":\"https://ping.lab:9032\",\"filter\":{\"ISSUER\":{\"CN\":\"Fle
EOF
cat /var/snap/chromium/current/policies/managed/fleet-autoselect.json`
- `11-chromium-policy-port-9032-launch.txt` (VM): `bash /tmp/br.sh chromium`
- `12-chromium-policy-port-9032.png` (VM screenshot)
- `13-chromium-policy-port-9032-callback-log.txt` (VM): `bash /tmp/killbr.sh`
{"policies":{"Preferences":{"security.default_personal_cert":{"Value":"Select Automatically","Status":"locked"
EOF
cat /usr/lib/firefox/distribution/policies.json`
- `14-firefox-harness-setting.txt` (VM): `echo 'user_pref("toolkit.startup.max_resumed_crashes", -1);' > /home/lab/.config/mozilla/firefox/ynqapdfi.defa`
- `15-firefox-policy-none.txt` (VM): `unlink /usr/lib/firefox/distribution/policies.json 2>/dev/null; ls /usr/lib/firefox/distribution; echo '(no po`
- `16-firefox-no-policy-launch.txt` (VM): `bash /tmp/br.sh firefox`
- `17-firefox-no-policy.png` (VM screenshot)
- `18-firefox-no-policy-callback-log.txt` (VM): `bash /tmp/killbr.sh`
- `19-firefox-policy-set.txt` (VM): `cat > /usr/lib/firefox/distribution/policies.json <<'EOF'
{"policies":{"Preferences":{"security.default_personal_cert":{"Value":"Select Automatically","Status":"locked"
EOF
cat /usr/lib/firefox/distribution/policies.json`
- `20-firefox-policy-select-automatically-launch.txt` (VM): `bash /tmp/br.sh firefox`
- `21-firefox-policy-select-automatically.png` (VM screenshot)
- `22-firefox-policy-select-automatically-callback-log.txt` (VM): `bash /tmp/killbr.sh`
- `23-firefox-no-policy-picker-prep.txt` (VM): `unlink /usr/lib/firefox/distribution/policies.json 2>/dev/null; ls /usr/lib/firefox/distribution; echo '(polic`
- `24-firefox-no-policy-picker-launch.txt` (VM): `bash /tmp/br.sh firefox`
- `25-firefox-no-policy-picker-at-13s.png` (VM screenshot)
- `26-firefox-picker-close.txt` (VM): `bash /tmp/killbr.sh`
- `27-firefox-policy-restore.txt` (VM): `cat > /usr/lib/firefox/distribution/policies.json <<'EOF'
{"policies":{"Preferences":{"security.default_personal_cert":{"Value":"Select Automatically","Status":"locked"
EOF
cat /usr/lib/firefox/distribution/policies.json`

## Result: **PASS**

Chromium (snap) shows the Select a certificate picker with no policy and with a policy for the wrong port (9031); AutoSelectCertificateForUrls for https://ping.lab:9032 with an issuer filter skips the picker and reaches the callback. Firefox (deb) shows its picker with no policy (and times out if nobody answers) and security.default_personal_cert = Select Automatically skips it. The pattern must name the host and port that request the certificate (the adapter Client Auth port), not the sign-in URL port. Lab notes: Chromium needed --ozone-platform=wayland in this VM and trust for the lab CA root in its NSS store; the harness needed a Firefox crash-prompt setting.

_Finished 2026-10-07T18:41:40Z_
