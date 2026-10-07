. evidence/lib.sh
CHP=/var/snap/chromium/current/policies/managed
[ "$ONLY" = firefox ] || ev_init P-14 "Skipping the certificate picker in Chromium and Firefox on Linux" "Chromium and Firefox show a certificate picker by default; the documented policies make them pick the Fleet certificate automatically." "Picker without a policy; no picker with the right policy; picker still shown if the policy names the wrong port (9031)." >/dev/null
step() { # label browser
  ev_vm P-14 "$1-launch" "bash /tmp/br.sh $2" >/dev/null; sleep 40; ev_shot P-14 "$1" >/dev/null
  ev_vm P-14 "$1-callback-log" "bash /tmp/killbr.sh" >/dev/null
}
if [ "$ONLY" != firefox ]; then
ev_vm P-14 lab-prerequisite-trust-root "certutil -A -d sql:/home/lab/snap/chromium/current/.pki/nssdb -n FleetLabCAroot -t CT,, -i /opt/company/step-ca-root.crt; chown -R lab:lab /home/lab/snap/chromium/current/.pki; certutil -L -d sql:/home/lab/snap/chromium/current/.pki/nssdb | head -6; echo 'Lab prerequisite: the browser must trust the CA that issued the PingFederate server certificate. The P-3 reset had removed this trust for Chromium.'" >/dev/null
ev_vm P-14 chromium-policy-none "mkdir -p $CHP; mv $CHP/lab-autoselect.json /tmp/lab-autoselect.json.bak 2>/dev/null; unlink $CHP/fleet-autoselect.json 2>/dev/null; echo 'policy directory contents:'; ls -la $CHP; echo '(no policy files)'" >/dev/null
step chromium-no-policy chromium
ev_vm P-14 chromium-policy-wrong-port "cat > $CHP/fleet-autoselect.json <<'EOF'
{\"AutoSelectCertificateForUrls\": [\"{\\\"pattern\\\":\\\"https://ping.lab:9031\\\",\\\"filter\\\":{\\\"ISSUER\\\":{\\\"CN\\\":\\\"Fleet Lab CA Intermediate CA\\\"}}}\"]}
EOF
cat $CHP/fleet-autoselect.json" >/dev/null
step chromium-policy-port-9031 chromium
ev_vm P-14 chromium-policy-right-port "cat > $CHP/fleet-autoselect.json <<'EOF'
{\"AutoSelectCertificateForUrls\": [\"{\\\"pattern\\\":\\\"https://ping.lab:9032\\\",\\\"filter\\\":{\\\"ISSUER\\\":{\\\"CN\\\":\\\"Fleet Lab CA Intermediate CA\\\"}}}\"]}
EOF
cat $CHP/fleet-autoselect.json" >/dev/null
step chromium-policy-port-9032 chromium
fi
ev_vm P-14 firefox-harness-setting "echo 'user_pref(\"toolkit.startup.max_resumed_crashes\", -1);' > /home/lab/.config/mozilla/firefox/ynqapdfi.default-release/user.js; chown lab:lab /home/lab/.config/mozilla/firefox/ynqapdfi.default-release/user.js; cat /home/lab/.config/mozilla/firefox/ynqapdfi.default-release/user.js; echo 'Test harness setting only: the harness kills the browser between cases, which otherwise triggers the Troubleshoot Mode prompt.'" >/dev/null
ev_vm P-14 firefox-policy-none "unlink /usr/lib/firefox/distribution/policies.json 2>/dev/null; ls /usr/lib/firefox/distribution; echo '(no policies.json)'" >/dev/null
step firefox-no-policy firefox
ev_vm P-14 firefox-policy-set "cat > /usr/lib/firefox/distribution/policies.json <<'EOF'
{\"policies\":{\"Preferences\":{\"security.default_personal_cert\":{\"Value\":\"Select Automatically\",\"Status\":\"locked\"}}}}
EOF
cat /usr/lib/firefox/distribution/policies.json" >/dev/null
step firefox-policy-select-automatically firefox
