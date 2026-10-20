#!/usr/bin/env bash
# Fleet API helpers for the ITAM tests (fleetdm/fleet#38864). Source this file:
#   . testing/servicenow-itam-38864/scripts/fleet-api.sh
# Reads FLEET_URL and FLEET_API_TOKEN from the environment, or from the KEY=VALUE file in SECRETS_ENV.
# The token goes to curl on stdin as a config line, so it never shows in argv, ps output or ev_cmd logs.
# Endpoints follow docs/REST API/rest-api.md in fleetdm/fleet (4.93.0).

_itam_load_env() {
  if [ -z "${FLEET_URL:-}" ] || [ -z "${FLEET_API_TOKEN:-}" ]; then
    if [ -n "${SECRETS_ENV:-}" ] && [ -f "$SECRETS_ENV" ]; then
      FLEET_URL="${FLEET_URL:-$(sed -n 's/^FLEET_URL=//p' "$SECRETS_ENV" | tr -d '"'"'" | head -1)}"
      FLEET_API_TOKEN="${FLEET_API_TOKEN:-$(sed -n 's/^FLEET_API_TOKEN=//p' "$SECRETS_ENV" | tr -d '"'"'" | head -1)}"
    fi
  fi
  : "${FLEET_URL:?set FLEET_URL or SECRETS_ENV}"
  : "${FLEET_API_TOKEN:?set FLEET_API_TOKEN or SECRETS_ENV}"
  export FLEET_URL FLEET_API_TOKEN
}

# fleet_get <path> [query-string]   prints the JSON body
fleet_get() {
  _itam_load_env
  local url="${FLEET_URL%/}$1"
  [ -n "${2:-}" ] && url="$url?$2"
  printf 'header = "Authorization: Bearer %s"\n' "$FLEET_API_TOKEN" |
    curl -fsS --retry 2 --connect-timeout 15 -K - -H 'Accept: application/json' "$url"
}

# fleet_report_id <exact report name> <fleet_id>   ("List reports"; 4.93 returns "reports" and "queries")
fleet_report_id() {
  fleet_get /api/v1/fleet/reports "fleet_id=$2&merge_inherited=true&per_page=1000" |
    jq -r --arg n "$1" '((.reports // .queries) // [])[] | select(.name == $n) | .id' | head -1
}

# fleet_hosts <fleet_id>   ("List hosts" with end users, one JSON object per line)
fleet_hosts() {
  local page=0 body
  while :; do
    body=$(fleet_get /api/v1/fleet/hosts "fleet_id=$1&populate_end_users=true&per_page=100&page=$page")
    jq -c '.hosts[]' <<<"$body"
    [ "$(jq '.hosts | length' <<<"$body")" -lt 100 ] && break
    page=$((page + 1))
  done
}

# fleet_host_software <host_id>   ("Get host's software", every page, one title per line)
fleet_host_software() {
  local page=0 body
  while :; do
    body=$(fleet_get "/api/v1/fleet/hosts/$1/software" "per_page=200&page=$page")
    jq -c '.software[]' <<<"$body"
    [ "$(jq -r '.meta.has_next_results // false' <<<"$body")" = true ] || break
    page=$((page + 1))
  done
}

# fleet_host <host_id>   ("Get host", without software, includes policies)
fleet_host() { fleet_get "/api/v1/fleet/hosts/$1" "exclude_software=true"; }

export -f _itam_load_env fleet_get fleet_report_id fleet_hosts fleet_host_software fleet_host
