# Replaces fleet 10's enroll secrets for X-3, then puts the GitOps value back. Prints the status and a short SHA-256 of
# each secret, never the secret. Usage: python3 -I tools/fleet-secret.py rotate|restore|show
# The GitOps value comes from private/.env, so restore leaves the fleet as fleet.mpc.ad's GitOps run would.
import hashlib, json, os, re, secrets, sys, urllib.request
cfg = open(os.path.expanduser("~/.fleet/config")).read().split("default:", 1)[1]
addr = re.search(r"address:\s*(\S+)", cfg).group(1); tok = re.search(r"token:\s*(\S+)", cfg).group(1)
env = dict(l.strip().split("=", 1) for l in open("private/.env") if "=" in l and not l.startswith("#"))
gitops = env["FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET"].strip().strip('"').strip("'")
h = lambda s: hashlib.sha256(s.encode()).hexdigest()[:8]
def call(method, body=None):
    req = urllib.request.Request(addr + "/api/v1/fleet/teams/10/secrets", method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    r = urllib.request.urlopen(req); return r.status, json.load(r)
mode = sys.argv[1]
if mode == "rotate": st, j = call("PATCH", {"secrets": [{"secret": secrets.token_urlsafe(24)}]})
elif mode == "restore": st, j = call("PATCH", {"secrets": [{"secret": gitops}]})
else: st, j = call("GET")
print(mode, st, "secrets:", [h(s["secret"]) for s in j["secrets"]], "| GitOps value:", h(gitops))
