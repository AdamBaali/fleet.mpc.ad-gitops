#!/bin/bash
# Run PowerShell in a VM started by qemu-boot.sh, through the QEMU guest agent.
# Usage: qga.sh <name> '<powershell>' [timeout seconds]
# The script goes in base64 so quoting and the guest keyboard layout don't matter.
set -euo pipefail
sock=${VM_ROOT:-$PWD/out/qemu}/$1/qga.sock
exec python3 -I - "$sock" "$2" "${3:-120}" <<'PY'
import base64,json,socket,sys,time
sock,ps,timeout=sys.argv[1],sys.argv[2],int(sys.argv[3])
s=socket.socket(socket.AF_UNIX); s.settimeout(timeout+10); s.connect(sock); f=s.makefile("rw")
def call(cmd,**a):
    f.write(json.dumps({"execute":cmd,"arguments":a} if a else {"execute":cmd})+"\n"); f.flush()
    while True:
        r=json.loads(f.readline())
        if "return" in r or "error" in r: return r
sid=int(time.time()*1000)%2**31
call("guest-sync",id=sid)
enc=base64.b64encode(("$ProgressPreference='SilentlyContinue';"+ps).encode("utf-16-le")).decode()
pid=call("guest-exec",path="powershell.exe",arg=["-NoProfile","-NonInteractive","-EncodedCommand",enc],**{"capture-output":True})["return"]["pid"]
end=time.time()+timeout
while time.time()<end:
    r=call("guest-exec-status",pid=pid)["return"]
    if r["exited"]:
        for k in ("out-data","err-data"):
            if k in r: sys.stdout.write(base64.b64decode(r[k]).decode("utf-8","replace"))
        sys.exit(r.get("exitcode",0))
    time.sleep(1)
sys.exit("timeout")
PY
