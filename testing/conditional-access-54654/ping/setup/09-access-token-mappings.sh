#!/usr/bin/env bash
# The OAuth server only offers an authentication source that has an Access Token Mapping into the
# client's access token manager. Without these the authorization request fails with
# "There are no authentication methods available for OAuth".
. "$(dirname "$0")/lib.sh"
mk() { # context-type context-ref-id
  local BODY; BODY="$(jq -n --arg t "$1" --arg c "$2" --arg b "$PF_API" '{
    id: ($t + "|" + $c + "|atmref"),
    context: {type: $t, contextRef: {id: $c, location: ($b + "/oauth/accessTokenMappings")}},
    accessTokenManagerRef: {id: "atmref"},
    attributeContractFulfillment: {sub: {source: {type: "OAUTH_PERSISTENT_GRANT"}, value: "USER_KEY"}}}')"
  pf -X POST "$PF_API/oauth/accessTokenMappings" -d "$BODY" | jq -c '{created:.id}'
}
mk IDP_ADAPTER x509lab
mk AUTHENTICATION_POLICY_CONTRACT fleetcontract
