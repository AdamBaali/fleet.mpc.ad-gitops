#!/usr/bin/env bash
# Fleet-side lever for E-2: change host 14's end user email so the sync matches it to managed-test, or stops matching.
# usage: tools/fleet-email.sh show
#        tools/fleet-email.sh custom managed|dummy   custom email (source custom); the sync ignores it unless EMAIL_SOURCES has custom
#        tools/fleet-email.sh idp managed|dummy      IdP username set by an admin (Fleet reports it as mdm_idp_accounts)
#        tools/fleet-email.sh idp-delete             remove the IdP username (DELETE /hosts/14/device_mapping/idp)
# managed = managed-test@mpc.ad, dummy = fleet-e2-dummy@example.com (no Google user).
# Uses fleetctl's default context (admin). Only touches host 14 (fleet "iOS Google Lab"). Prints the email's local part only.
set -euo pipefail
HOST=14
fleetctl() { command fleetctl "$@" 2> >(grep -v -e "Version mismatch" -e "Client Version" -e "Server Version" >&2); }
email_for() { case "$1" in managed) echo managed-test@mpc.ad;; dummy) echo fleet-e2-dummy@example.com;; *) echo "managed or dummy, not '$1'" >&2; exit 2;; esac; }
show() { fleetctl api "/hosts/$HOST/device_mapping" | jq -r --arg t "$(date -u +%H:%M:%SZ)" \
  '"\($t) host \(.host_id) device_mapping: " + ([.device_mapping[] | "\(.source)=\(.email | split("@")[0])@…"] | join(", "))'; }
team=$(fleetctl api "/hosts/$HOST" | jq -r '.host.team_name')
[ "$team" = "iOS Google Lab" ] || { echo "host $HOST is in '$team', not iOS Google Lab. Stopping." >&2; exit 1; }
case "${1:?usage: tools/fleet-email.sh show | custom managed|dummy | idp managed|dummy | idp-delete}" in
  show) ;;
  custom|idp)
    email=$(email_for "${2:?managed or dummy}")
    fleetctl api -X PUT -F email="$email" -F source="$1" "/hosts/$HOST/device_mapping" >/dev/null
    echo "$(date -u +%H:%M:%SZ) PUT /hosts/$HOST/device_mapping source=$1 email=$(cut -d@ -f1 <<<"$email")@…" ;;
  idp-delete)
    fleetctl api -X DELETE "/hosts/$HOST/device_mapping/idp" >/dev/null
    echo "$(date -u +%H:%M:%SZ) DELETE /hosts/$HOST/device_mapping/idp" ;;
  *) echo "unknown action: $1" >&2; exit 2 ;;
esac
show
