#!/usr/bin/env bash
# Base URL must match what browsers and the X.509 adapter use: https://ping.lab:9031
. "$(dirname "$0")/lib.sh"
CUR="$(pf "$PF_API/serverSettings")"
pf -X PUT "$PF_API/serverSettings" -d "$(jq '.federationInfo.baseUrl = "https://ping.lab:9031"' <<<"$CUR")" | jq -c '{baseUrl:.federationInfo.baseUrl}'
pf -X PUT "$PF_API/virtualHostNames" -d '{"virtualHostNames":["ping.lab"]}' | jq -c '.'
