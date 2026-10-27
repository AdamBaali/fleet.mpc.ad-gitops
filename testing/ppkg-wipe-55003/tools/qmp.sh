#!/bin/bash
# Talk to a VM started by tools/qemu-boot.sh.
# Usage: tools/qmp.sh <name> shot <out.png> | keys <key> [key...] | type '<text>' | click <x> <y> | shell | quit
# click scales from an 800x600 screen unless SHOT names a screenshot of the current size. | '<raw json>'
# Keys use QEMU names (ret, shift, f10, a, ...); several keys in one call are pressed together.
set -euo pipefail
name=$1 cmd=$2; shift 2
sock=$(cd "$(dirname "$0")/.." && pwd)/out/qemu/$name/qmp.sock
send() { python3 -I - "$sock" "$1" <<'EOF'
import json,socket,sys
s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f=s.makefile("rw")
f.readline(); f.write('{"execute":"qmp_capabilities"}\n'); f.flush(); f.readline()
f.write(sys.argv[2]+"\n"); f.flush()
while True:
    r=json.loads(f.readline())
    if "event" not in r: print(json.dumps(r.get("return",r))); break
EOF
}
case $cmd in
  shot) case $1 in /*) ;; *) set -- "$PWD/$1";; esac
        send "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$1.ppm\"}}" >/dev/null
        sips -s format png "$1.ppm" --out "$1" >/dev/null && rm "$1.ppm" && echo "$1" ;;
  keys) k=$(printf '{"type":"qcode","data":"%s"},' "$@"); send "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[${k%,}]}}" ;;
  type) python3 -I "$(dirname "$0")/qmp-keys.py" "$1" | while read -r j; do send "$j" >/dev/null; done ;;
  click) # x y in screenshot pixels; the tablet takes 0..32767 across the current screen size.
        read -r w h < <(sips -g pixelWidth -g pixelHeight "${SHOT:-/dev/null}" 2>/dev/null | awk '/pixel/{print $2}' | paste -sd' ' -)
        w=${w:-800} h=${h:-600}; x=$(( $1 * 32767 / w )) y=$(( $2 * 32767 / h ))
        # Move, press, release as separate events with pauses: Windows drops a click sent in one burst.
        send "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"abs\",\"data\":{\"axis\":\"x\",\"value\":$x}},{\"type\":\"abs\",\"data\":{\"axis\":\"y\",\"value\":$y}}]}}" >/dev/null
        sleep 0.3
        send '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":true,"button":"left"}}]}}' >/dev/null
        sleep 0.15
        send '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":false,"button":"left"}}]}}' ;;
  shell) # Command prompt over Windows setup. It opens without keyboard focus, so click its title bar.
        "$0" "$name" keys shift f10 >/dev/null; sleep 6; "$0" "$name" click 200 93 >/dev/null; sleep 1 ;;
  quit) send '{"execute":"quit"}' ;;
  *)    send "$cmd" ;;
esac
