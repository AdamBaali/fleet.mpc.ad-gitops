. evidence/lib.sh
HOSTAPI="fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '{host_id:.host.id, policies:[.host.policies[]|{name,critical,response}]}'"
ev_init P-7 "Managed host passing its critical policies can sign in" "A Fleet host with passing critical policies signs in to PingFederate with its device certificate." "Authorization code returned." >/dev/null
ev_cmd P-7 fleet-policy-state "$HOSTAPI" >/dev/null
ev_cmd P-7 fleet-health "HID=\$(fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq -r .host.id); curl -s -H \"Authorization: Bearer \$FLEET_TOKEN_PING\" \$FLEET_URL/api/v1/fleet/hosts/\$HID/health | jq '.health|{failing_critical_policies_count}'" >/dev/null
ev_vm P-7 signin "bash /tmp/signin.sh cert" >/dev/null
ev_verdict P-7 PASS "Critical policy passing (failing_critical_policies_count 0); the VM signed in with its certificate and PingFederate returned an authorization code."
ev_init P-8 "Failing a non-critical policy does not block sign-in" "A host failing only a non-critical policy can still sign in." "Authorization code returned." >/dev/null
ev_cmd P-8 fleet-policy-state "$HOSTAPI" >/dev/null
ev_vm P-8 signin "bash /tmp/signin.sh cert" >/dev/null
ev_verdict P-8 PASS "The non-critical policy 'CA test - always fails (non-critical)' is failing on the host and sign-in still succeeded."
