#!/usr/bin/env bash
# Guide Step 5: Fleet as a REST API data store. Bearer token comes from .env (FLEET_TOKEN_PING).
. "$(dirname "$0")/lib.sh"
ID=fleet-rest
BODY="$(jq -n --arg id "$ID" --arg url "$FLEET_URL" --arg tok "$FLEET_TOKEN_PING" '{
  type: "CUSTOM", id: $id, name: "Fleet",
  pluginDescriptorRef: {id: "com.pingidentity.pf.datastore.other.RestDataSourceDriver"},
  configuration: {
    fields: [
      {name: "Base URL", value: $url},
      {name: "Authentication Method", value: "None"},
      {name: "HTTP Method", value: "GET"},
      {name: "Test Connection URL", value: ($url + "/api/v1/fleet/me")}
    ],
    tables: [
      {name: "HTTP Request Headers", rows: [{fields: [
        {name: "Header Name", value: "Authorization"}, {name: "Header Value", value: ("Bearer " + $tok)}]}]},
      {name: "Attributes", rows: [
        {fields: [{name: "Local Attribute", value: "fleetHostUUID"}, {name: "JSON Response Attribute Path", value: "/host/uuid"}]},
        {fields: [{name: "Local Attribute", value: "fleetHostID"}, {name: "JSON Response Attribute Path", value: "/host/id"}]},
        {fields: [{name: "Local Attribute", value: "failingCriticalPolicies"}, {name: "JSON Response Attribute Path", value: "/health/failing_critical_policies_count"}]}]}
    ]}}')"
if exists "/dataStores/$ID"; then pf -X PUT "$PF_API/dataStores/$ID" -d "$BODY" | jq -r '"updated data store \(.id)"'
else pf -X POST "$PF_API/dataStores" -d "$BODY" | jq -r '"created data store \(.id)"'; fi
# Guide Step 5 / test P-5: run the data store's "Test Connection" action (its ID is generated, so look it up by name).
AID="$(pf "$PF_API/dataStores/$ID/actions" | jq -r '.items[]|select(.name=="Test Connection")|.id')"
echo "connection test:"
pf -X POST "$PF_API/dataStores/$ID/actions/$AID/invokeAction" -d '{"parameters":[]}' | jq -c '.'
