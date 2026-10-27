# Sends a JSON body (POST, or METHOD=PATCH) to the lab Fleet with the fleetctl context's token, and prints the status and body.
# fleetctl api can't send nested JSON (-F makes flat fields). Usage: python3 -I tools/fleet-post.py <path> '<json>'
import json, os, sys, urllib.request, re
cfg = open(os.path.expanduser("~/.fleet/config")).read()
ctx = cfg.split("default:", 1)[1]
addr = re.search(r"address:\s*(\S+)", ctx).group(1); tok = re.search(r"token:\s*(\S+)", ctx).group(1)
req = urllib.request.Request(addr + sys.argv[1], data=sys.argv[2].encode(), method=os.environ.get("METHOD", "POST"),
                             headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
try:
    r = urllib.request.urlopen(req); print(r.status, r.read().decode()[:600])
except urllib.error.HTTPError as e:
    print(e.code, e.read().decode()[:600])
