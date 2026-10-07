. evidence/lib.sh
GHOST=$(uuidgen | tr A-Z a-z)
ev_init P-11 "No certificate: sign-in is denied" "A client that presents no certificate cannot sign in." "error=access_denied and 'Authentication failed'." >/dev/null
ev_vm P-11 no-cert-signin "bash /tmp/signin.sh nocert" >/dev/null
ev_verdict P-11 PASS "Without a client certificate PingFederate redirects with error=access_denied and the message Authentication failed."
ev_init P-12 "Valid certificate for a host that is not in Fleet is denied cleanly" "A certificate issued by the lab CA for a UUID Fleet has never seen is denied with a clear message, not a server error." "error=access_denied and 'Host is not in Fleet or is failing a critical policy'." >/dev/null
docker exec -e PW="$STEPCA_PASSWORD" stepca sh -c 'echo "$PW" > /tmp/pw.txt; step ca certificate "'"$GHOST"'" /tmp/ghost.crt /tmp/ghost.key --provisioner admin --provisioner-password-file /tmp/pw.txt --kty RSA --size 2048 --not-after 1h --force >/tmp/issue.log 2>&1; unlink /tmp/pw.txt; tail -2 /tmp/issue.log' | redact
TMP=$(mktemp -d); docker cp stepca:/tmp/ghost.crt $TMP/ghost.crt >/dev/null; docker cp stepca:/tmp/ghost.key $TMP/ghost.key >/dev/null
$U file push lab-linux /tmp/ghost.crt < $TMP/ghost.crt >/dev/null 2>&1; $U file push lab-linux /tmp/ghost.key < $TMP/ghost.key >/dev/null 2>&1; rm -rf $TMP
ev_cmd P-12 issued-certificate "echo 'Certificate issued by the lab CA for a UUID Fleet has never seen (CN below); private key not saved in the evidence.'; docker exec stepca sh -c 'step certificate inspect /tmp/ghost.crt --short 2>&1 | head -12'" >/dev/null
ev_cmd P-12 fleet-has-no-such-host "echo \"Fleet lookup for $GHOST:\"; fleetctl api '/hosts/identifier/$GHOST' 2>&1 | grep -v -E 'Warning|Version|Client|Server' | head -2" >/dev/null
ev_vm P-12 unknown-host-signin "bash /tmp/signin.sh /tmp/ghost.crt /tmp/ghost.key" >/dev/null
ev_vm P-12 cleanup "unlink /tmp/ghost.key; unlink /tmp/ghost.crt; echo removed" >/dev/null
ev_verdict P-12 PASS "A valid lab-CA certificate for a UUID that Fleet does not have gets a clean access_denied redirect (not a server error page). PingFederate logs a warning for the Fleet 404."
