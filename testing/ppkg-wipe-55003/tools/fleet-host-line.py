# One line of a Fleet host's enrollment state, from GET /api/v1/fleet/hosts/:id on stdin.
import json, sys
try:
    h = json.load(sys.stdin)["host"]
except Exception:
    print("lookup failed")
    sys.exit()
m = h.get("mdm") or {}
users = [e.get("idp_username") or e.get("email") for e in (h.get("end_users") or [])]
print("host={} name={} status={} enrolled={} restarted={} mdm={} connected={} orbit={} users={}".format(
    h["id"], h["hostname"], h["status"], h["last_enrolled_at"], h.get("last_restarted_at"),
    m.get("enrollment_status"), m.get("connected_to_fleet"), h.get("orbit_version"), users))
