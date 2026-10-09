#!/usr/bin/env bash
# Local lever for E-2: read or write the Fleet client state of one Google device user directly (no Fleet, no workflow).
# usage: tools/state.sh get|managed|unmanaged [email]     default email: managed-test@mpc.ad
# Writes exactly what the sync script writes (MANAGED/COMPLIANT/customId 14, or UNMANAGED/NON_COMPLIANT/no customId), then
# reads it back. Prints UTC times, the state and the device ID prefix only. Never the token or the key.
# The scheduled google-sync loop rewrites the state from Fleet every ~5 minutes: pause it first (see RUNBOOK_E2_C2.md).
set -euo pipefail
cd "$(dirname "$0")/.."
ACTION="${1:?usage: tools/state.sh get|managed|unmanaged [email]}"; EMAIL="${2:-managed-test@mpc.ad}"
case "$ACTION" in get|managed|unmanaged) ;; *) echo "unknown action: $ACTION" >&2; exit 2;; esac
tools/google-token.sh >/dev/null
python3 -I - "$ACTION" "$EMAIL" <<'PY'
import json, sys, time, urllib.request, urllib.error
action, email = sys.argv[1], sys.argv[2].lower()
env = dict(l.split("=", 1) for l in open(".env").read().splitlines() if "=" in l and not l.startswith("#"))
tok = open("secrets/google-access-token").read().strip()
partner = env["GOOGLE_CUSTOMER_ID"].lstrip("C") + "-fleet"
def call(method, path, body=None):
    req = urllib.request.Request("https://cloudidentity.googleapis.com/v1/" + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    try: return 200, json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode() or "{}")
        except Exception: return e.code, {}
now = lambda: time.strftime("%H:%M:%SZ", time.gmtime())
code, du = call("GET", "devices/-/deviceUsers?customer=customers/my_customer&pageSize=100")
users = [u for u in du.get("deviceUsers", []) if u.get("userEmail", "").lower() == email]
if not users: sys.exit(f"{now()} no Google device user for {email.split('@')[0]} (sign in to Drive on the phone first)")
for u in users:
    dev = u["name"].split("/")[1][:6] + "…"
    path = f"{u['name']}/clientStates/{partner}?customer=customers/my_customer"
    if action != "get":
        body = ({"managed": "MANAGED", "complianceState": "COMPLIANT", "customId": "14"} if action == "managed"
                else {"managed": "UNMANAGED", "complianceState": "NON_COMPLIANT", "customId": ""})
        code, r = call("PATCH", path + "&updateMask=managed,complianceState,customId", body)
        print(f"{now()} PATCH {email.split('@')[0]} dev {dev} -> {body['managed']}: HTTP {code}"
              + ("" if code == 200 else f" {r.get('error', {}).get('message', '')[:120]}"))
    code, s = call("GET", path)
    print(f"{now()} GET   {email.split('@')[0]} dev {dev}: HTTP {code} managed={s.get('managed')} "
          f"compliance={s.get('complianceState')} customId={s.get('customId') or '-'} updated={s.get('lastUpdateTime')}")
PY
