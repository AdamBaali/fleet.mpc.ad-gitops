#!/bin/bash
# Copy a file from the Mac into a VM started by tools/qemu-boot.sh, through the guest agent.
# Usage: tools/qga-push.sh <name> <local file> <guest path>
# Lab shortcut for putting the MSI or package on a host, in place of a download or a Fleet software package.
set -euo pipefail
sock=$(cd "$(dirname "$0")/.." && pwd)/out/qemu/$1/qga.sock
exec python3 -I - "$sock" "$2" "$3" <<'PY'
import base64,json,socket,sys,hashlib
sock,src,dst=sys.argv[1:4]
s=socket.socket(socket.AF_UNIX); s.settimeout(120); s.connect(sock); f=s.makefile("rw")
def call(cmd,**a):
    f.write(json.dumps({"execute":cmd,"arguments":a})+"\n"); f.flush()
    while True:
        r=json.loads(f.readline())
        if "return" in r: return r["return"]
        if "error" in r: sys.exit(r["error"]["desc"])
call("guest-sync",id=42)
h=call("guest-file-open",path=dst,mode="wb")
data=open(src,"rb").read()
for i in range(0,len(data),1<<20):
    call("guest-file-write",handle=h,**{"buf-b64":base64.b64encode(data[i:i+(1<<20)]).decode()})
call("guest-file-close",handle=h)
print(dst,len(data),hashlib.sha256(data).hexdigest().upper())
PY
