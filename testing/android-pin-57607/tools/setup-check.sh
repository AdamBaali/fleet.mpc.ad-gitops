#!/usr/bin/env bash
# Read-only checks for TEST-PLAN.md S-1 to S-3. Prints only the fields the plan records.
# Usage: setup-check.sh version|fleets|profiles|labels|config
# Needs FLEET_URL and FLEET_API_TOKEN (run.sh loads them from private/fleet.env).
set -euo pipefail
: "${FLEET_URL:?set FLEET_URL}" "${FLEET_API_TOKEN:?set FLEET_API_TOKEN}"
get() { curl -sS --fail-with-body -H "Authorization: Bearer $FLEET_API_TOKEN" "${FLEET_URL%/}$1"; }
py() { python3 -I -c "$1"; }

case "${1:?see the header}" in
  version) get /api/v1/fleet/version | py 'import json,sys; print(json.load(sys.stdin)["version"])' ;;
  fleets)
    get /api/v1/fleet/fleets | py '
import json, sys
d = json.load(sys.stdin)
for f in d.get("fleets", d.get("teams", [])):
    if f["name"].startswith("android-pin"):
        print(f["id"], f["name"])' ;;
  profiles)
    # Fleet IDs come from the fleets check, so the profile list follows whatever GitOps created.
    for id in $("$0" fleets | cut -d" " -f1); do
      printf "fleet %s: " "$id"
      get "/api/v1/fleet/configuration_profiles?fleet_id=$id" | py '
import json, sys
d = json.load(sys.stdin)
print([(p["name"], p.get("platform"), [l["name"] for l in p.get("labels_include_any") or []]) for p in d.get("profiles") or []])'
    done ;;
  labels)
    get /api/v1/fleet/labels | py '
import json, sys
for l in json.load(sys.stdin)["labels"]:
    if l["name"].startswith("android-pin"):
        print(l["name"], l.get("label_membership_type"), "fleet_id=%s" % l.get("fleet_id", l.get("team_id")))' ;;
  config)
    get /api/v1/fleet/config | py '
import json, sys
d = json.load(sys.stdin)
print("android_enabled_and_configured:", d["mdm"]["android_enabled_and_configured"])
print("gitops.exceptions:", d["gitops"]["exceptions"])' ;;
  *) echo "unknown check $1" >&2; exit 2 ;;
esac
