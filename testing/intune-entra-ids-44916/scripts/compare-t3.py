"""Compare the IDs fake-ids.ps1 wrote with what the Fleet API returns. Prints one verdict per check.
Usage: compare-t3.py <vm> <host id> <intune report id> <entra report id>
Response fields are read defensively because the report and host-report endpoints shape rows differently.
"""
import json
import subprocess
import sys

vm, host, rin, ren = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]


def api(path):
    return json.loads(subprocess.run(["scripts/fleet-api.sh", path], capture_output=True, text=True, check=True).stdout)


def vm_json(ps):
    out = subprocess.run(["tools/qga.sh", vm, ps], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def rows(resp):
    # /reports/:id/report returns results[{host_id, columns}]; /hosts/:id/reports/:id returns results[{columns}]
    out = []
    for r in resp.get("results") or []:
        cols = r.get("columns", r)
        out.append((r.get("host_id", host), cols))
    return out


expected = vm_json("Get-Content -Raw C:\\ids\\expected.json")
checks = []


def check(name, ok, detail):
    checks.append(ok)
    print(f"{'PASS' if ok else 'FAIL'}  {name}: {detail}")


for label, rid, col, want in (("intune", rin, "intune_device_id", expected["intune_device_id"]),
                              ("entra", ren, "entra_device_id", expected["entra_device_id"])):
    allr = api(f"/api/v1/fleet/reports/{rid}/report?page=0&per_page=500")
    mine = [c for h, c in rows(allr) if h == host]
    check(f"{label} report: one row for host {host}", len(mine) == 1, f"{len(mine)} rows")
    check(f"{label} report: value", bool(mine) and mine[0].get(col) == want, f"got {mine[0].get(col) if mine else None}, want {want}")
    check(f"{label} report: not clipped", allr.get("report_clipped") is False, f"report_clipped={allr.get('report_clipped')}")
    hr = rows(api(f"/api/v1/fleet/hosts/{host}/reports/{rid}"))
    check(f"{label} host endpoint: value", len(hr) == 1 and hr[0][1].get(col) == want, f"{len(hr)} rows, got {hr[0][1].get(col) if hr else None}")

intune = rows(api(f"/api/v1/fleet/reports/{rin}/report?page=0&per_page=500"))
key = expected["enrollment_key"]
check("intune report: enrollment key returned", any(key in (c.get("enrollment_key") or "") for _, c in intune), key)
print("ALL PASS" if all(checks) else "SOME FAILED")
sys.exit(0 if all(checks) else 1)
