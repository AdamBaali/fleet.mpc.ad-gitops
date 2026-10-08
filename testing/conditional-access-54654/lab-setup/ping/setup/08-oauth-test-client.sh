#!/usr/bin/env bash
# Phase 4 step 4 (last bullet): a test OAuth client so a browser sign-in can be started at
#   https://ping.lab:9031/as/authorization.oauth2?client_id=labclient&response_type=code&redirect_uri=http://localhost:8765/callback
. "$(dirname "$0")/lib.sh"
upsert() { # path id body
  if exists "$1/$2"; then pf -X PUT "$PF_API$1/$2" -d "$3" | jq -c '{updated:(.id // .clientId)}'
  else pf -X POST "$PF_API$1" -d "$3" | jq -c '{created:(.id // .clientId)}'; fi
}
upsert /oauth/accessTokenManagers atmref '{
  "id":"atmref","name":"Reference tokens",
  "pluginDescriptorRef":{"id":"org.sourceid.oauth20.token.plugin.impl.ReferenceBearerAccessTokenManagementPlugin"},
  "configuration":{"fields":[{"name":"Token Length","value":"28"},{"name":"Token Lifetime","value":"120"}]},
  "attributeContract":{"coreAttributes":[],"extendedAttributes":[{"name":"sub","multiValued":false}]}}'
# Policy contract -> persistent grant. Issuance criteria live on the policy tree node (07), per guide Step 6.
MAP='{"authenticationPolicyContractRef":{"id":"fleetcontract"},
  "attributeContractFulfillment":{
    "USER_KEY":{"source":{"type":"AUTHENTICATION_POLICY_CONTRACT"},"value":"subject"},
    "USER_NAME":{"source":{"type":"AUTHENTICATION_POLICY_CONTRACT"},"value":"subject"}}}'
if exists "/oauth/authenticationPolicyContractMappings/fleetcontract"; then
  pf -X PUT "$PF_API/oauth/authenticationPolicyContractMappings/fleetcontract" -d "$MAP" | jq -c '{updated:.id}'
else pf -X POST "$PF_API/oauth/authenticationPolicyContractMappings" -d "$MAP" | jq -c '{created:.id}'; fi
upsert /oauth/clients labclient '{
  "clientId":"labclient","name":"Lab test client","enabled":true,
  "grantTypes":["AUTHORIZATION_CODE"],
  "redirectUris":["http://localhost:8765/callback"],
  "bypassApprovalPage":true,
  "defaultAccessTokenManagerRef":{"id":"atmref"},
  "clientAuth":{"type":"NONE"}}'
