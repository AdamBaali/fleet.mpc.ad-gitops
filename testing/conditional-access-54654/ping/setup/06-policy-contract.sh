#!/usr/bin/env bash
# Guide Step 6 (first half): authentication policy contract the adapter's success path maps into.
. "$(dirname "$0")/lib.sh"
ID=fleetcontract
BODY="$(jq -n --arg id "$ID" '{id:$id, name:"Fleet device check", coreAttributes:[{name:"subject"}], extendedAttributes:[{name:"hostUUID"},{name:"fleetHostID"}]}')"
if exists "/authenticationPolicyContracts/$ID"; then pf -X PUT "$PF_API/authenticationPolicyContracts/$ID" -d "$BODY" | jq -c '{updated:.id}'
else pf -X POST "$PF_API/authenticationPolicyContracts" -d "$BODY" | jq -c '{created:.id}'; fi
