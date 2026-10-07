. evidence/lib.sh
S=ping/setup; PFA='https://localhost:9999/pf-admin-api/v1'; AUTH="-u Administrator:\$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate'"
restore() { (cd $S && bash ./07-auth-policy.sh >/dev/null 2>&1); for v in A C D; do unlink $S/.var-$v.sh 2>/dev/null; done; }
trap restore EXIT
logsince() { docker exec pingfederate sh -c "tail -n +$1 /opt/out/instance/log/server.log" | grep -E "Unknown Key|Comparison Value|Actual Value|Authorization failed|Problem with attribute lookup" | sed -E 's/^[0-9-]+ ([0-9:,]+) tid:[A-Za-z0-9_-]+ /\1 /' | cut -c1-420; }
mark() { docker exec pingfederate sh -c 'wc -l < /opt/out/instance/log/server.log'; }
ev_init P-6 "Lookup variable names in the authentication policy" "Find which names PingFederate accepts in the Fleet lookup paths and issuance criteria, and what happens with the guide's wording." "Names of the form \${ad.<adapter ID>.CN} and \${ds.<source ID>.<attribute>} work; \${hostUUID} and \${fleetHostID} do not." >/dev/null
ev_cmd P-6 policy-as-configured "curl -sk $AUTH $PFA/authenticationPolicies/default | jq '.authnSelectionTrees[0].rootNode.children[1].action.attributeMapping | {lookup_1:.attributeSources[0].filterFields[0].value, lookup_2:.attributeSources[1].filterFields[0].value, contract_fulfillment_keys:(.attributeContractFulfillment|keys), issuance_criteria:[.issuanceCriteria.conditionalCriteria[]|{source:.source.id,attribute:.attributeName,condition,value}]}'" >/dev/null
ev_vm P-6 baseline-signin "bash /tmp/signin.sh cert" >/dev/null
(cd $S
 sed -e 's#\${ad.x509lab.'"'"'"\$SRC_ATTR"'"'"'}#${hostUUID}#' 07-auth-policy.sh > .var-A.sh
 sed -e 's#issuanceCriteria: {conditionalCriteria: \[#issuanceCriteria: {conditionalCriteria: [{source: {type: "CUSTOM_DATA_STORE", id: "fleetByUuid"}, attributeName: "fleetHostUUID", condition: "EQUALS", value: "${hostUUID}", errorResult: "uuid mismatch"},#' 07-auth-policy.sh > .var-C.sh
 sed -e 's#\${ds.fleetByUuid.fleetHostID}#${fleetHostID}#' 07-auth-policy.sh > .var-D.sh)
for v in A C D; do
  case $v in A) t="A: guide wording \${hostUUID} in lookup 1";; C) t="C: second criterion fleetHostUUID equals \${hostUUID} (guide wording)";; D) t="D: guide wording \${fleetHostID} in lookup 2";; esac
  tq=$(printf "%q" "$t"); ev_cmd P-6 "variant-$v-apply" "echo $tq; (cd $S && bash ./.var-$v.sh | tail -1)" >/dev/null
  m=$(mark)
  ev_vm P-6 "variant-$v-signin" "bash /tmp/signin.sh cert" >/dev/null
  ev_cmd P-6 "variant-$v-log" "echo 'PingFederate server log, decoded (lines written during that sign-in):'; docker exec pingfederate sh -c 'tail -n +$m /opt/out/instance/log/server.log' | grep -E 'Unknown Key|Comparison Value|Actual Value|Authorization failed' | python3 evidence/logkeys.py" >/dev/null
done
restore; trap - EXIT
ev_cmd P-6 restore-and-signin "echo 'Working policy restored.'; echo" >/dev/null
ev_vm P-6 restored-signin "bash /tmp/signin.sh cert" >/dev/null
