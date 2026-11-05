"""Reads Fleet's "Get host by identifier" JSON on stdin and prints only what TEST-PLAN.md records."""
import json
import sys

d = json.load(sys.stdin)
h = d.get("host")
if not h:
    sys.exit("no host in the response: %s" % d.get("message", d))
mdm = h.get("mdm") or {}
out = {
    "id": h.get("id"),
    "platform": h.get("platform"),
    "os_version": h.get("os_version"),
    "hardware_vendor": h.get("hardware_vendor"),
    "hardware_model": h.get("hardware_model"),
    # Fleet 4.9x sends both during the team -> fleet rename.
    "fleet": h.get("fleet_name") or h.get("team_name") or "Unassigned",
    "created_at": h.get("created_at"),
    "last_enrolled_at": h.get("last_enrolled_at"),
    "detail_updated_at": h.get("detail_updated_at"),
    "mdm_enrollment_status": mdm.get("enrollment_status"),
    "labels": sorted(l["name"] for l in h.get("labels") or [] if l.get("label_type") != "builtin"),
    "profiles": [
        {k: p.get(k) for k in ("name", "status", "operation_type", "detail")}
        for p in mdm.get("profiles") or []
    ],
}
print(json.dumps(out, indent=2))
