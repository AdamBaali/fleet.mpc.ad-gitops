#!/usr/bin/env python3
"""Run a cmd.exe command line in the QEMU clone via the guest agent (SYSTEM). usage: vm/qga-cmd.py '<cmd line>' [timeout_s]"""
import base64, json, os, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.settimeout(120)
s.connect(os.path.join(os.path.dirname(os.path.abspath(__file__)), "run", "qga.sock")); f = s.makefile("r")
def c(m):
    s.sendall(json.dumps(m).encode() + b"\n")
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r: return r
c({"execute": "guest-sync", "arguments": {"id": 31337}})
pid = c({"execute": "guest-exec", "arguments": {"path": "cmd.exe", "arg": ["/c", sys.argv[1]], "capture-output": True}})["return"]["pid"]
end = time.time() + float(sys.argv[2] if len(sys.argv) > 2 else 90)
while time.time() < end:
    r = c({"execute": "guest-exec-status", "arguments": {"pid": pid}})["return"]
    if r.get("exited"):
        for k in ("out-data", "err-data"):
            if r.get(k): sys.stdout.write(base64.b64decode(r[k]).decode("utf-8", "replace"))
        print("[exit %s]" % r.get("exitcode")); sys.exit(0)
    time.sleep(1)
print("[timeout, pid %s]" % pid)
