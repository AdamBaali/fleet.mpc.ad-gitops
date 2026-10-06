# Shared helpers for the PingFederate Admin API setup scripts.
# Source from a script in this directory. Reads ../../.env (never prints secrets).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB="$(cd "$HERE/../.." && pwd)"
set -a; . "$LAB/.env"; set +a
PF_API="${PF_API:-https://localhost:9999/pf-admin-api/v1}"
# pf <curl args...>: authenticated call, JSON in/out. Fails on HTTP >= 400 and prints the body.
pf() {
  local out code
  out="$(mktemp)"
  code="$(curl -sk -o "$out" -w '%{http_code}' -u "Administrator:${PING_ADMIN_PASSWORD}" \
    -H 'X-XSRF-Header: PingFederate' -H 'Content-Type: application/json' "$@")"
  if [ "$code" -ge 400 ]; then echo "HTTP $code from: ${*: -1}" >&2; sed -E 's/Bearer [A-Za-z0-9+\/=_-]+/Bearer <redacted>/g' "$out" >&2; echo >&2; rm -f "$out"; return 1; fi
  cat "$out"; rm -f "$out"
}
# exists <path>: true if GET returns 200
exists() { curl -sk -o /dev/null -w '%{http_code}' -u "Administrator:${PING_ADMIN_PASSWORD}" -H 'X-XSRF-Header: PingFederate' "$PF_API$1" | grep -q '^200$'; }
