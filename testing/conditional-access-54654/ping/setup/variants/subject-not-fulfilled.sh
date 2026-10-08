#!/usr/bin/env bash
# Guide Step 6: authentication policy. X.509 adapter -> on success, map to the policy contract with
# two Fleet lookups and the issuance criteria. Variables below are the knobs under test (P-6).
. "$(dirname "$0")/lib.sh"
SRC_ATTR="${SRC_ATTR:-CN}"            # adapter attribute that carries the certificate CN
# Adapter attributes are keyed ad.<adapter id>.<attribute> in lookup paths; plain ${CN} or ${hostUUID} is "Unknown Key".
LOOKUP1='/api/v1/fleet/hosts/identifier/${ad.x509lab.'"$SRC_ATTR"'}?exclude_software=true'
# A data store attribute is only fetched if something references it, and a later lookup sees it as ds.<source id>.<attribute>.
LOOKUP2='/api/v1/fleet/hosts/${ds.fleetByUuid.fleetHostID}/health'
POLICY="$(jq -n --arg l1 "$LOOKUP1" --arg l2 "$LOOKUP2" --arg src "$SRC_ATTR" '{
  failIfNoSelection: false,
  authnSelectionTrees: [{
    name: "Fleet device check", enabled: true, handleFailuresLocally: false,
    rootNode: {
      action: {type: "AUTHN_SOURCE", authenticationSource: {type: "IDP_ADAPTER", sourceRef: {id: "x509lab"}}},
      children: [
        {action: {type: "DONE", context: "Fail"}, children: []},
        {action: {type: "APC_MAPPING", context: "Success", authenticationPolicyContractRef: {id: "fleetcontract"},
          attributeMapping: {
            attributeSources: [
              {type: "CUSTOM", id: "fleetByUuid", description: "Fleet host by UUID", dataStoreRef: {id: "fleet-rest"},
               filterFields: [{name: "Resource Path", value: $l1}], attributeContractFulfillment: {}},
              {type: "CUSTOM", id: "fleetHealth", description: "Fleet host health", dataStoreRef: {id: "fleet-rest"},
               filterFields: [{name: "Resource Path", value: $l2}], attributeContractFulfillment: {}}],
            attributeContractFulfillment: {
              hostUUID: {source: {type: "ADAPTER", id: "x509lab"}, value: $src},
              fleetHostID: {source: {type: "CUSTOM_DATA_STORE", id: "fleetByUuid"}, value: "fleetHostID"}},
            # The guide adds "fleetHostUUID equals ${hostUUID}" as a second criterion. A condition value is literal
            # text (PingFederate logged "Comparison Value: ${hostUUID}"), so it can never match, and expression
            # criteria are disabled by default. One criterion is enough: if the host is not in Fleet, lookup 2
            # cannot resolve ds.fleetByUuid.fleetHostID, failingCriticalPolicies has no value, and "equals 0" fails.
            issuanceCriteria: {conditionalCriteria: [
              {source: {type: "CUSTOM_DATA_STORE", id: "fleetHealth"}, attributeName: "failingCriticalPolicies",
               condition: "EQUALS", value: "0", errorResult: "Host is not in Fleet or is failing a critical policy"}]}}}, children: []}]}}],
  defaultAuthenticationSources: []}')"
pf -X PUT "$PF_API/authenticationPolicies/settings" -d '{"enableIdpAuthnSelection":true,"enableSpAuthnSelection":true}' | jq -c '.'
pf -X PUT "$PF_API/authenticationPolicies/default" -d "$POLICY" | jq -c '{trees:(.authnSelectionTrees|length)}'
