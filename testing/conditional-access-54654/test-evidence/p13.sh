. evidence/lib.sh
UUID=86d7dc8e-3373-47af-86dd-56a1cd517e2f
ev_init P-13 "A new host signs in before its first policy run" "A host that has just enrolled in Fleet has no policy results yet. Unrun policies are not counted as failing, so sign-in succeeds (the guide may need to say so)." "Authorization code returned while the host's policy responses are still empty." >/dev/null
ev_cmd P-13 host-before "fleetctl api '/hosts/identifier/$UUID' 2>/dev/null | jq '{id:.host.id, uuid:.host.uuid, status:.host.status, enrolled:.host.last_enrolled_at}'" >/dev/null
OLD=$(fleetctl api "/hosts/identifier/$UUID" 2>/dev/null | jq -r .host.id)
ev_cmd P-13 delete-host "T0=\$(date +%s); fleetctl api -X DELETE /hosts/$OLD 2>&1 | grep -v -E 'Warning|Version|Client|Server'; echo \"host $OLD deleted\"; fleetctl api '/hosts/identifier/$UUID' 2>&1 | grep -v -E 'Warning|Version|Client|Server' | head -1" >/dev/null
ev_cmd P-13 wait-for-reenrollment "t0=\$(date +%s); for i in \$(seq 1 40); do r=\$(fleetctl api '/hosts/identifier/$UUID' 2>/dev/null | jq -c '{id:.host.id,status:.host.status,policies_with_results:([.host.policies[]?|select(.response!=null and .response!=\"\")]|length)}' 2>/dev/null); if [ -n \"\$r\" ]; then echo \"T+\$((\$(date +%s)-t0))s host is back: \$r\"; break; fi; echo \"T+\$((\$(date +%s)-t0))s not enrolled yet\"; sleep 3; done" >/dev/null
ev_cmd P-13 host-just-enrolled "fleetctl api '/hosts/identifier/$UUID' 2>/dev/null | jq '{id:.host.id, status:.host.status, enrolled:.host.last_enrolled_at, policies:[.host.policies[]?|{name,critical,response}]}'" >/dev/null
ev_vm P-13 signin-right-away "bash /tmp/signin.sh cert" >/dev/null
ev_cmd P-13 health-right-away "HID=\$(fleetctl api '/hosts/identifier/$UUID' 2>/dev/null | jq -r .host.id); curl -s -H \"Authorization: Bearer \$FLEET_TOKEN_PING\" \$FLEET_URL/api/v1/fleet/hosts/\$HID/health | jq '.health|{failing_critical_policies_count}'" >/dev/null
