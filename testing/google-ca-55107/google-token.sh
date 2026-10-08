#!/bin/bash
# Prints a Google access token for the service account, acting as the admin (domain-wide delegation).
# Use it only in a pipe or command substitution, never echo it:
#   GOOGLE_ACCESS_TOKEN=$(tools/google-token.sh) DRY_RUN=true FLEET_API_TOKEN=... ./sync.sh
# Needs GOOGLE_SA_KEY_FILE (path to the JSON key, outside the repo) and GOOGLE_ADMIN_EMAIL in .env. Needs jq, openssl, curl.
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
: "${GOOGLE_SA_KEY_FILE:?Set GOOGLE_SA_KEY_FILE in .env}" "${GOOGLE_ADMIN_EMAIL:?Set GOOGLE_ADMIN_EMAIL in .env}"
scope="${GOOGLE_SCOPE:-https://www.googleapis.com/auth/cloud-identity.devices}"
b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
client_email=$(jq -r .client_email "$GOOGLE_SA_KEY_FILE")
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64)
claims=$(jq -nc --arg iss "$client_email" --arg sub "$GOOGLE_ADMIN_EMAIL" --arg scope "$scope" --argjson now "$now" \
  '{iss: $iss, sub: $sub, scope: $scope, aud: "https://oauth2.googleapis.com/token", iat: $now, exp: ($now + 3600)}' | b64)
sig=$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign <(jq -r .private_key "$GOOGLE_SA_KEY_FILE") | b64)
curl -fsS https://oauth2.googleapis.com/token \
  --data-urlencode grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
  --data-urlencode "assertion=$header.$claims.$sig" | jq -er .access_token
