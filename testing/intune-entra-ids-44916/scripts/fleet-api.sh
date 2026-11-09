#!/bin/bash
# GET a lab Fleet API path and print the JSON. Usage: fleet-api.sh /api/v1/fleet/...
# Reads the lab URL and token from FLEET_ENV (default: the android-pin project's private env).
# The token goes in through a curl config on stdin, so it never reaches argv or evidence.
set -euo pipefail
env_file=${FLEET_ENV:-$(dirname "$0")/../../android-pin-57607/private/fleet.env}
set -a; . "$env_file"; set +a
[[ "$FLEET_URL" == https://fleet.mpc.ad* ]] || { echo "refusing: not the lab Fleet" >&2; exit 1; }
printf 'header = "Authorization: Bearer %s"\n' "$FLEET_API_TOKEN" | curl -sS --fail-with-body -K - "$FLEET_URL$1"
