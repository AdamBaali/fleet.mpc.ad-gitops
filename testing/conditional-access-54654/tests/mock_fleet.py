# Mock Fleet API for export-fleet-hosts-for-duo.sh. 1,109 hosts across platforms, critical/non-critical policy results,
# a MachineGuid report with a duplicate row and a row for a deleted host. Serves on 127.0.0.1:8899.
import json, http.server, urllib.parse
def pol(c,r): return {"id":1,"critical":c,"response":r}
H=[
 {"id":1,"platform":"darwin","uuid":"MAC-PASS","policies":[pol(True,"pass"),pol(False,"fail")]},
 {"id":2,"platform":"darwin","uuid":"MAC-FAILCRIT","policies":[pol(True,"fail")]},
 {"id":3,"platform":"windows","uuid":"WIN-UUID-3","policies":[pol(True,"pass")]},
 {"id":4,"platform":"windows","uuid":"WIN-UUID-4","policies":[pol(True,"fail")]},
 {"id":5,"platform":"windows","uuid":"WIN-NO-REPORT","policies":[]},
 {"id":6,"platform":"ubuntu","uuid":"lin-ubuntu","policies":[]},
 {"id":7,"platform":"rhel","uuid":"lin-rhel","policies":[pol(True,"")]},
 {"id":8,"platform":"ios","uuid":"IOS","policies":[]},
 {"id":9,"platform":"chrome","uuid":"CHROME","policies":[]},
]+[{"id":100+i,"platform":"darwin","uuid":f"MAC-BULK-{i}","policies":[]} for i in range(1100)]
R=[{"host_id":3,"columns":{"machine_guid":"guid-3"}},{"host_id":4,"columns":{"machine_guid":"guid-4"}},
   {"host_id":3,"columns":{"machine_guid":"guid-3"}},{"host_id":99,"columns":{"machine_guid":"guid-deleted"}}]
class S(http.server.BaseHTTPRequestHandler):
  def log_message(s,*a): pass
  def do_GET(s):
    u=urllib.parse.urlparse(s.path); q=urllib.parse.parse_qs(u.query)
    if u.path=="/api/v1/fleet/hosts":
      p=int(q["page"][0]); n=int(q["per_page"][0]); pp=q.get("populate_policies",["false"])[0]=="true"
      b=[dict(h) for h in H[p*n:(p+1)*n]]
      if not pp: [h.pop("policies") for h in b]
      body={"hosts":b}
    elif u.path=="/api/v1/fleet/reports/42/report": body={"results":R}
    else: s.send_response(404); s.end_headers(); return
    d=json.dumps(body).encode(); s.send_response(200); s.end_headers(); s.wfile.write(d)
http.server.HTTPServer(("127.0.0.1",8899),S).serve_forever()
