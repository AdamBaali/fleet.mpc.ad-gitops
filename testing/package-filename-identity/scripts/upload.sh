#!/usr/bin/env bash
# Uploads one package to a Fleet fleet, optionally as another package of an existing title,
# the same request the "Add package" button on a software title page sends.
# Prints the HTTP status, the response message, and the file's SHA-256 so each result shows
# whether the bytes matched the base package.
#
# Usage: upload.sh <file> <fleet id> [title id] [install script file] [uninstall script file]
# Needs FLEET_URL and FLEET_API_TOKEN from the environment or from FLEET_ENV (default ./private/fleet.env).
set -euo pipefail
file="${1:?usage: upload.sh <file> <fleet id> [title id] [install script] [uninstall script]}"
fleet_id="${2:?fleet id}"; title_id="${3:-}"; install="${4:-}"; uninstall="${5:-}"
env_file="${FLEET_ENV:-$PWD/private/fleet.env}"
[ -f "$env_file" ] && { set -a; . "$env_file"; set +a; }
: "${FLEET_URL:?set FLEET_URL}" "${FLEET_API_TOKEN:?set FLEET_API_TOKEN}"

args=(-F "software=@$file" --form-string "fleet_id=$fleet_id")
[ -n "$title_id" ] && args+=(--form-string "software_title_id=$title_id")
# .tar.gz and .zip packages have no default scripts, so Fleet rejects them without both.
[ -n "$install" ] && args+=(--form-string "install_script=$(cat "$install")")
[ -n "$uninstall" ] && args+=(--form-string "uninstall_script=$(cat "$uninstall")")

echo "file:     $(basename "$file")"
echo "sha256:   $(shasum -a 256 "$file" | cut -d' ' -f1)"
echo "title_id: ${title_id:-<none, new title>}"
body=$(mktemp); trap 'rm -f "$body"' EXIT
code=$(curl -sS -o "$body" -w '%{http_code}' -H "Authorization: Bearer $FLEET_API_TOKEN" \
  "${args[@]}" "${FLEET_URL%/}/api/v1/fleet/software/package")
echo "http:     $code"
python3 -I -c '
import json, sys
raw = open(sys.argv[1]).read()
try:
    d = json.loads(raw)
except ValueError:
    print("message:  " + raw.strip()[:300]); sys.exit()
errs = d.get("errors") or []
print("message:  " + ("; ".join(e.get("reason", "") for e in errs) if errs else d.get("message", "<none>")))
for k in ("software_title_id", "software_package", "title_id"):
    if k in d: print("%-9s %s" % (k + ":", d[k]))
' "$body"
