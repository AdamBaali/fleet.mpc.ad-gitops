#!/bin/bash
# Script template used in this guide: https://fleetdm.com/guides/google-conditional-access-integration
# Tells Google which iPhones and iPads are managed by Fleet, by setting a client state under your
# partner ID that Context-Aware Access checks. Google doesn't record serial numbers for iPhones and
# iPads, so the script matches them to Fleet hosts by end user email and device type. It stores the
# Fleet host ID and the serial number (as an asset tag) on the client state, so admins can see which
# Fleet host Google trusts (Admin console > the device > Third-party services).
# Set DRY_RUN=true to print changes without making them. Needs curl and jq.
set -euo pipefail

FLEET_URL="${FLEET_URL:-https://fleet.example.com}"
FLEET_API_TOKEN="${FLEET_API_TOKEN:?Set FLEET_API_TOKEN}"
GOOGLE_ACCESS_TOKEN="${GOOGLE_ACCESS_TOKEN:?Set GOOGLE_ACCESS_TOKEN}"
GOOGLE_CUSTOMER_ID="${GOOGLE_CUSTOMER_ID:-<customer-ID>}" # as shown in Admin console > Account settings, starts with C
PARTNER_ID="${GOOGLE_CUSTOMER_ID#C}-fleet" # Google wants the customer ID WITHOUT the leading C here
# Which Fleet emails count, comma-separated. Default: the IdP email from enrollment (end user authentication, or an IdP
# username set by an admin). Add "custom" to also use emails set through the API or the UI.
EMAIL_SOURCES="${EMAIL_SOURCES:-mdm_idp_accounts}"
DRY_RUN="${DRY_RUN:-false}"

fleet() {
  curl -fsS -H "Authorization: Bearer $FLEET_API_TOKEN" "$FLEET_URL/api/v1/fleet/$1"
}

google() { # method path [body]
  curl -fsS -X "$1" -H "Authorization: Bearer $GOOGLE_ACCESS_TOKEN" -H "Content-Type: application/json" \
    "https://cloudidentity.googleapis.com/v1/$2" ${3:+--data "$3"}
}

google_list() { # path key: prints each item under key, across all pages
  local token="" page
  while :; do
    page=$(google GET "$1&pageSize=100&pageToken=$token")
    jq -c ".$2[]?" <<<"$page"
    token=$(jq -r '.nextPageToken // empty' <<<"$page")
    [ -z "$token" ] && break
  done
}

page=0
hosts="[]"
while :; do
  batch=$(fleet "hosts?per_page=50&page=$page&device_mapping=true" | jq '.hosts')
  [ "$(jq length <<<"$batch")" -eq 0 ] && break
  hosts=$(jq -s 'add' <(echo "$hosts") <(echo "$batch"))
  page=$((page + 1))
done

# iPhones and iPads with MDM on in Fleet.
managed=$(jq '[.[] | select((.platform == "ios" or .platform == "ipados") and ((.mdm.enrollment_status // "") | startswith("On")))]' <<<"$hosts")
# Their Fleet host IDs, keyed by "<end user email>/<iphone|ipad>" (emails from EMAIL_SOURCES only), and each one's serial number.
fleet_keys=$(jq --arg sources "$EMAIL_SOURCES" '
  ($sources | split(",")) as $ok
  | [.[] | (if .platform == "ipados" then "ipad" else "iphone" end) as $kind | .id as $id
   | (.device_mapping // [])[] | select(.source as $s | $ok | index($s)) | {key: ((.email | ascii_downcase) + "/" + $kind), id: $id}]
  | unique | group_by(.key) | map({key: .[0].key, value: map(.id)}) | from_entries' <<<"$managed")
serials=$(jq 'map({key: (.id | tostring), value: (.hardware_serial // "")}) | from_entries' <<<"$managed")

# Refuse to run when Fleet returns no managed iPhones or iPads. Otherwise a wrong token scope or an outage would mark every Google device unmanaged.
if [ "$(jq 'length' <<<"$fleet_keys")" -eq 0 ] && [ "${ALLOW_EMPTY:-false}" != true ]; then
  echo "Fleet returned no managed iPhones or iPads with an email from $EMAIL_SOURCES. Not changing anything. Set ALLOW_EMPTY=true to override." >&2
  exit 1
fi

devices=$(google_list "devices?customer=customers/my_customer&view=USER_ASSIGNED_DEVICES" devices | jq -s '
  map(select(.deviceType == "IOS") | {key: .name, value: (if ((.model // "") | test("^ipad"; "i")) then "ipad" else "iphone" end)})
  | from_entries')
users=$(google_list "devices/-/deviceUsers?customer=customers/my_customer" deviceUsers | jq -s --argjson devices "$devices" '
  map((.name | split("/deviceUsers/")[0]) as $d | select($devices | has($d))
    | {name, key: (((.userEmail // "") | ascii_downcase) + "/" + $devices[$d])})')
google_counts=$(jq 'group_by(.key) | map({key: .[0].key, value: length}) | from_entries' <<<"$users")

changes=0
while read -r user; do
  name=$(jq -r .name <<<"$user")
  key=$(jq -r .key <<<"$user")
  fleet_count=$(jq --arg k "$key" '.[$k] // [] | length' <<<"$fleet_keys")
  google_count=$(jq --arg k "$key" '.[$k]' <<<"$google_counts")

  host_id=""
  if [ "$fleet_count" -eq 1 ] && [ "$google_count" -eq 1 ]; then
    host_id=$(jq -r --arg k "$key" '.[$k][0]' <<<"$fleet_keys")
  elif [ "$fleet_count" -gt 0 ]; then
    # Don't guess. Google blocks the device until the match is unambiguous.
    echo "Review: $key has $fleet_count Fleet hosts and $google_count Google devices. Not marking $name as managed." >&2
  fi

  # Use my_customer: with domain-wide delegation, customers/<ID> returns 400 (tested). Google's own sample sends no customer.
  state="$name/clientStates/$PARTNER_ID?customer=customers/my_customer"
  current=$(google GET "$state" 2>/dev/null | jq -c '{managed: (.managed // ""), assetTags: (.assetTags // [])}' ||
    jq -nc '{managed: "", assetTags: []}')
  if [ -n "$host_id" ]; then
    want=$(jq -nc --arg serial "$(jq -r --arg id "$host_id" '.[$id]' <<<"$serials")" '{managed: "MANAGED", assetTags: ([$serial] - [""])}')
  else
    want=$(jq -nc '{managed: "UNMANAGED", assetTags: []}')
  fi
  was=$(jq -r .managed <<<"$current")
  now=$(jq -r .managed <<<"$want")
  # Context-Aware Access already blocks devices that Fleet never marked as managed.
  if [ -z "$was" ] && [ "$now" = UNMANAGED ]; then continue; fi
  if [ "$current" = "$want" ]; then continue; fi

  echo "$name ($key): ${was:-none} -> $now$([ "$was" = "$now" ] && echo " (serial number updated)" || true)"
  changes=$((changes + 1))
  if [ "$DRY_RUN" = true ]; then continue; fi
  google PATCH "$state&updateMask=managed,complianceState,customId,assetTags" "$(jq -c --arg id "$host_id" \
    '{managed, complianceState: (if .managed == "MANAGED" then "COMPLIANT" else "NON_COMPLIANT" end), customId: $id, assetTags}' <<<"$want")" >/dev/null
done < <(jq -c '.[]' <<<"$users")

echo "Fleet: $(jq length <<<"$managed") managed iPhones and iPads, $(jq '[.[][]] | unique | length' <<<"$fleet_keys") with an email from $EMAIL_SOURCES. Google: $(jq length <<<"$users") iPhone and iPad users. Changes: $changes$([ "$DRY_RUN" = true ] && echo " (dry run)" || true)."
