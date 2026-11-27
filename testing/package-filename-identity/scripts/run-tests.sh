#!/usr/bin/env bash
# Runs T-0 to T-6 from TEST_PLAN.md against the Package Identity Lab fleet and saves evidence.
# Run from testing/package-filename-identity/ after the fleet exists in Fleet (merged to main):
#   bash scripts/run-tests.sh
# T-1 to T-6 add packages to the lab fleet. A GitOps apply removes them (see HANDOFF.md).
set -euo pipefail
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$P"
REPO="$(cd "$P/../.." && pwd)"
export FLEET_ENV="${FLEET_ENV:-$P/private/fleet.env}"
export SECRETS_ENV="$FLEET_ENV"
export EV="$P/test-evidence/lab"; mkdir -p "$EV"
. "$REPO/testing/_framework/bin/ev.sh"
set -a; . "$FLEET_ENV"; set +a
api() { curl -sS --fail-with-body -H "Authorization: Bearer $FLEET_API_TOKEN" "${FLEET_URL%/}$1"; }
UP="$P/scripts/upload.sh"
BASE="$REPO/lib/linux/software/package-identity-probe.sh"
FLEET_NAME="Package Identity Lab"

# Every test file is built here from the committed base package, so "identical bytes" is exact.
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/same" "$W/renamed" "$W/v2-renamed" "$W/v2-same" "$W/tgz"
cp "$BASE" "$W/same/package-identity-probe.sh"
cp "$BASE" "$W/renamed/package-identity-probe-test.sh"
sed 's/ v1 / v2 /' "$BASE" > "$W/v2-renamed/package-identity-probe-v2.sh"
sed 's/ v1 / v2 /' "$BASE" > "$W/v2-same/package-identity-probe.sh"
printf '#!/bin/sh\necho install\n' > "$W/tgz/install.sh"
printf '#!/bin/sh\necho uninstall\n' > "$W/tgz/uninstall.sh"
mk_tgz() { # name, version text: a .tar.gz with one file whose contents differ by version
  mkdir -p "$W/tgz/src-$2"; echo "probe tool $2" > "$W/tgz/src-$2/probe-tool.txt"
  tar -czf "$W/tgz/$1" -C "$W/tgz/src-$2" probe-tool.txt
}
mk_tgz probe-tool.tar.gz v1
mk_tgz probe-tool-test.tar.gz v2

ev_init T-0 "Lab setup" "Record the Fleet version, the lab fleet, and the base title" \
  "Fleet 4.90 or later; the fleet has one script package titled package-identity-probe"
ev_cmd T-0 fleet-version "'$REPO/testing/_framework/bin/fleet-api.sh' version"
FLEET_ID=$(api /api/v1/fleet/fleets | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print(next(t["id"] for t in d.get("fleets") or d.get("teams") if t["name"] == sys.argv[1]))' "$FLEET_NAME")
TITLE_ID=$(api "/api/v1/fleet/software/titles?fleet_id=$FLEET_ID&available_for_install=true&query=package-identity-probe" |
  python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print(next(t["id"] for t in d["software_titles"] if t["name"] == "package-identity-probe"))')
ev_note T-0 "Fleet \`$FLEET_NAME\` is id $FLEET_ID. Title \`package-identity-probe\` is id $TITLE_ID."
ev_cmd T-0 base-title "curl -sS -H 'Authorization: Bearer \$FLEET_API_TOKEN' '${FLEET_URL%/}/api/v1/fleet/software/titles/$TITLE_ID?fleet_id=$FLEET_ID' | python3 -I -c 'import json,sys; t=json.load(sys.stdin)[\"software_title\"]; print(t[\"name\"]); [print(p.get(\"name\"), p.get(\"version\"), p.get(\"hash_sha256\")) for p in (t.get(\"software_packages\") or ([t[\"software_package\"]] if t.get(\"software_package\") else []))]'"
ev_verdict T-0 INFO "Fleet id $FLEET_ID, title id $TITLE_ID"

run() { # id, title, objective, expected, file, [extra upload args]
  local id="$1" t="$2" o="$3" e="$4" f="$5"; shift 5
  ev_init "$id" "$t" "$o" "$e" >/dev/null
  ev_cmd "$id" upload "'$UP' '$f' $FLEET_ID $*"
}

run T-1 "Same name, same bytes" "Control: re-add the exact base file to its title" \
  "409, the hash conflict message" "$W/same/package-identity-probe.sh" "$TITLE_ID"
run T-2 "New name, same bytes" "The customer's case: the base file renamed with -test, bytes unchanged" \
  "Today (code read): 400 title mismatch. Asked for: the hash conflict message, since the bytes are already there" \
  "$W/renamed/package-identity-probe-test.sh" "$TITLE_ID"
run T-3 "New name, new bytes" "The feature request: a new version under a new filename, added to the chosen title" \
  "Today (code read): 400 title mismatch. Asked for: 200, a second package on the title" \
  "$W/v2-renamed/package-identity-probe-v2.sh" "$TITLE_ID"
run T-4 "Same name, new bytes" "Control: a new version with the base filename" \
  "200, a second package on the title" "$W/v2-same/package-identity-probe.sh" "$TITLE_ID"

# .tar.gz titles keep the extension in the name and have no metadata, so a rename is a new title too.
ev_init T-5 "tar.gz base title" "Add a .tar.gz package as a new title, the base for T-6" \
  "200, a new title named probe-tool.tar.gz" >/dev/null
ev_cmd T-5 upload "'$UP' '$W/tgz/probe-tool.tar.gz' $FLEET_ID '' '$W/tgz/install.sh' '$W/tgz/uninstall.sh'"
TGZ_TITLE=$(api "/api/v1/fleet/software/titles?fleet_id=$FLEET_ID&available_for_install=true&query=probe-tool" |
  python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print(next((t["id"] for t in d["software_titles"] if t["name"].startswith("probe-tool")), ""))')
ev_note T-5 "Title id for the .tar.gz: ${TGZ_TITLE:-<not found>}"
if [ -n "$TGZ_TITLE" ]; then
  run T-6 "tar.gz new name, new bytes" "The feature request on .tar.gz, a likely format for a Linux fleet" \
    "Today (code read): 400 title mismatch. Asked for: 200" \
    "$W/tgz/probe-tool-test.tar.gz" "$TGZ_TITLE" "'$W/tgz/install.sh'" "'$W/tgz/uninstall.sh'"
fi

echo; echo "Evidence in $EV. Set each verdict with ev_verdict after reading the output, then rebuild EVIDENCE.md."
