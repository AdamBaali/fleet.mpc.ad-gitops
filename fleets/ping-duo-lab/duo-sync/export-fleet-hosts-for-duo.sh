#!/bin/bash
# Script template used in this guide: https://fleetdm.com/guides/require-fleet-managed-hosts-in-duo
# Writes macos.csv, windows.csv, and linux.csv for Duo's device_cache_sync.py, with the
# device IDs of Fleet hosts. Set REQUIRE_PASSING_CRITICAL_POLICIES=true to only include hosts
# that are passing all critical policies. Needs curl and jq.
# The files are written to a temporary folder and moved into place only if everything succeeds.
# If a list is more than 50% smaller than the previous file in this folder, the script exits without
# replacing the files. Set FORCE=true to replace them anyway.
set -euo pipefail

FLEET_URL="https://fleet.mpc.ad"
FLEET_API_TOKEN="${FLEET_API_TOKEN:?Set FLEET_API_TOKEN}"
WINDOWS_REPORT_ID="69"
REQUIRE_PASSING_CRITICAL_POLICIES="${REQUIRE_PASSING_CRITICAL_POLICIES:-false}"
FORCE="${FORCE:-false}"

out=$(mktemp -d ./.duo-export.XXXXXX)
trap 'rm -rf "$out"' EXIT

api() {
  curl -fsS -H "Authorization: Bearer $FLEET_API_TOKEN" "$FLEET_URL/api/v1/fleet/$1"
}

page=0
hosts="[]"
while :; do
  batch=$(api "hosts?per_page=500&page=$page&populate_policies=$REQUIRE_PASSING_CRITICAL_POLICIES" | jq '.hosts')
  [ "$(jq length <<<"$batch")" -eq 0 ] && break
  hosts=$(jq -s 'add' <(echo "$hosts") <(echo "$batch"))
  page=$((page + 1))
done
trusted=$(jq --argjson require "$REQUIRE_PASSING_CRITICAL_POLICIES" '[.[] | select(($require | not) or ([.policies[]? | select(.critical and .response == "fail")] | length == 0))]' <<<"$hosts")

# Duo identifies macOS and Linux hosts by hardware UUID, the same as Fleet's host UUID.
jq -r '"device_id", (.[] | select(.platform == "darwin") | .uuid)' <<<"$trusted" >"$out/macos.csv"
jq -r '"device_id", (.[] | select(.platform as $p | ["darwin", "windows", "ios", "ipados", "android", "chrome"] | index($p) | not) | .uuid)' <<<"$trusted" >"$out/linux.csv"

# Duo identifies Windows hosts by MachineGuid, collected by the Fleet report.
api "reports/$WINDOWS_REPORT_ID/report" |
  jq -r --argjson trusted "$trusted" '
    ($trusted | map(select(.platform == "windows") | .id)) as $ids |
    "device_id", ([.results[] | select(.host_id as $h | $ids | index($h)) | .columns.machine_guid] | unique[])
  ' >"$out/windows.csv"

refused=false
for f in macos windows linux; do
  [ -f "$f.csv" ] || continue
  old=$(($(wc -l <"$f.csv") - 1))
  new=$(($(wc -l <"$out/$f.csv") - 1))
  if [ "$old" -gt 0 ] && [ $((new * 2)) -lt "$old" ] && [ "$FORCE" != "true" ]; then
    echo "Refusing to replace $f.csv: $old device IDs before, $new now. Set FORCE=true to continue." >&2
    refused=true
  fi
done
[ "$refused" = "true" ] && exit 1

mv "$out"/*.csv .
wc -l macos.csv windows.csv linux.csv
