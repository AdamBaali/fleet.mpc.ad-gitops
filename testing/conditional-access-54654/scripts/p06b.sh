. evidence/lib.sh
ev_init P-6b "fleetHostID does not need to be mapped" "Check whether the second lookup can use the first lookup's fleetHostID without mapping it to the policy contract." "Retest of an earlier finding that said it had to be mapped." >/dev/null
S=ping/setup
cat > $S/.p6b.sh <<'E'
set -uo pipefail
. ./lib.sh
CON=$(mktemp); pf "$PF_API/authenticationPolicyContracts/fleetcontract" > "$CON"
restore() { pf -X PUT "$PF_API/authenticationPolicyContracts/fleetcontract" -d @"$CON" >/dev/null && bash ./07-auth-policy.sh >/dev/null 2>&1; echo "[contract and policy restored]"; }
trap restore EXIT
echo "contract extended attributes before: $(jq -c '[.extendedAttributes[].name]' "$CON")"
jq '.extendedAttributes |= map(select(.name != "fleetHostID"))' "$CON" > "$CON.new"
pf -X PUT "$PF_API/authenticationPolicyContracts/fleetcontract" -d @"$CON.new" >/dev/null || exit 1
python3 - <<'P'
s=open('07-auth-policy.sh').read()
old='''              hostUUID: {source: {type: "ADAPTER", id: "x509lab"}, value: $src},
              fleetHostID: {source: {type: "CUSTOM_DATA_STORE", id: "fleetByUuid"}, value: "fleetHostID"}},'''
assert old in s
open('.p6b-policy.sh','w').write(s.replace(old,'''              hostUUID: {source: {type: "ADAPTER", id: "x509lab"}, value: $src}},'''))
P
bash ./.p6b-policy.sh >/dev/null || exit 1
echo "contract extended attributes now:    $(pf "$PF_API/authenticationPolicyContracts/fleetcontract" | jq -c '[.extendedAttributes[].name]')"
echo "contract fulfillment keys now:       $(pf "$PF_API/authenticationPolicies/default" | jq -c '[.authnSelectionTrees[0].rootNode.children[1].action.attributeMapping.attributeContractFulfillment|keys[]]')"
echo "lookup 2 still uses:                 $(pf "$PF_API/authenticationPolicies/default" | jq -r '.authnSelectionTrees[0].rootNode.children[1].action.attributeMapping.attributeSources[1].filterFields[0].value')"
MARK=$(docker exec pingfederate sh -c 'wc -l < /opt/out/instance/log/server.log'); echo "PingFederate log position before the sign-in: line $MARK"
bash <lab>/vm/linux/vm-run.sh 'bash /tmp/signin.sh cert' | sed -E 's/code=[A-Za-z0-9_.~-]+/code=<code>/'
echo "WARN/ERROR lines written to the PingFederate server log during that sign-in: $(docker exec pingfederate sh -c "tail -n +$MARK /opt/out/instance/log/server.log" | grep -c -E 'WARN|ERROR')"
unlink .p6b-policy.sh 2>/dev/null
E
ev_cmd P-6b unmapped-test "cd $S && bash .p6b.sh" >/dev/null
unlink $S/.p6b.sh
ev_cmd P-6b after-restore "echo 'Policy restored; baseline sign-in:'" >/dev/null
ev_vm P-6b restored-signin "bash /tmp/signin.sh cert" >/dev/null
