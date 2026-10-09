#!/usr/bin/env python3 -I
"""E-14: which partner ID form does Google accept for clientStates.patch? Run after the iPhone has signed in to a Google app.
Tries the form WITHOUT the leading C (Google's reference), WITH the C (the draft guide), and writes/reads back `managed`. Prints codes only, no tokens."""
import json, os, sys, urllib.request, urllib.error
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env = dict(l.split("=", 1) for l in open(os.path.join(ROOT, ".env")).read().splitlines() if "=" in l and not l.startswith("#"))
tok = open(os.path.join(ROOT, "secrets", "google-access-token")).read().strip()
cust = env["GOOGLE_CUSTOMER_ID"]
email = (sys.argv[1] if len(sys.argv) > 1 else "managed-test@mpc.ad").lower()
def call(method, path, body=None):
    req = urllib.request.Request("https://cloudidentity.googleapis.com/v1/" + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    try:
        return 200, json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode() or "{}")
        except Exception: return e.code, {}
code, du = call("GET", "devices/-/deviceUsers?customer=customers/my_customer&pageSize=100")
users = [u for u in du.get("deviceUsers", []) if (u.get("userEmail", "")).lower() == email]
print(f"deviceUsers.list: {code}; matching {email}: {len(users)}")
if not users: sys.exit("No device user for that email yet. Sign in to a Google app on the iPhone first.")
variants = {"no-C (Google reference)": cust.lstrip("C") + "-fleet", "with-C (draft guide)": cust + "-fleet"}
for u in users:
    for label, partner in variants.items():
        path = f"{u['name']}/clientStates/{partner}?customer=customers/{cust}&updateMask=managed,complianceState,customId"
        code, r = call("PATCH", path, {"managed": "MANAGED", "complianceState": "COMPLIANT", "customId": "e14-test"})
        print(f"  PATCH {label}: HTTP {code}" + ("" if code == 200 else f" {r.get('error', {}).get('status')}: {r.get('error', {}).get('message', '')[:120]}"))
        code, g = call("GET", f"{u['name']}/clientStates/{partner}?customer=customers/{cust}")
        print(f"  GET   {label}: HTTP {code}, managed={g.get('managed')}, compliance={g.get('complianceState')}")
