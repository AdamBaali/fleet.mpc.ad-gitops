. evidence/lib.sh
ev_init P-9 "Failing a critical policy denies sign-in" "When a critical policy fails and the host refetches, sign-in is denied with a clear message." "Sign-in redirects with error=access_denied and 'Host is not in Fleet or is failing a critical policy'." >/dev/null
ev_vm P-9 before "bash /tmp/signin.sh cert" >/dev/null
ev_cmd P-9 flip-to-failing "bash evidence/flip.sh fail" >/dev/null
ev_cmd P-9 fleet-policy-state "fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '[.host.policies[]|{name,critical,response}]'" >/dev/null
ev_vm P-9 signin-denied "bash /tmp/signin.sh cert" >/dev/null
ev_init P-10 "Fixing the critical policy restores sign-in" "After the policy passes again and the host refetches, the next sign-in works." "Fleet's count returns to 0 within about a minute and sign-in returns a code." >/dev/null
ev_cmd P-10 flip-to-passing "bash evidence/flip.sh pass" >/dev/null
ev_cmd P-10 fleet-policy-state "fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '[.host.policies[]|{name,critical,response}]'" >/dev/null
ev_vm P-10 signin-restored "bash /tmp/signin.sh cert" >/dev/null
