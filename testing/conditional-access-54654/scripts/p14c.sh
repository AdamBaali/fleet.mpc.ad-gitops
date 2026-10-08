. evidence/lib.sh
ev_vm P-14 firefox-no-policy-picker-prep "unlink /usr/lib/firefox/distribution/policies.json 2>/dev/null; ls /usr/lib/firefox/distribution; echo '(policies.json removed again for a quick look at the picker)'" >/dev/null
ev_vm P-14 firefox-no-policy-picker-launch "bash /tmp/br.sh firefox" >/dev/null; sleep 13; ev_shot P-14 firefox-no-policy-picker-at-13s >/dev/null
ev_vm P-14 firefox-picker-close "bash /tmp/killbr.sh" >/dev/null
ev_vm P-14 firefox-policy-restore "cat > /usr/lib/firefox/distribution/policies.json <<'EOF'
{\"policies\":{\"Preferences\":{\"security.default_personal_cert\":{\"Value\":\"Select Automatically\",\"Status\":\"locked\"}}}}
EOF
cat /usr/lib/firefox/distribution/policies.json" >/dev/null
