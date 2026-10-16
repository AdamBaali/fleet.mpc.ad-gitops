#!/usr/bin/env python3
"""Click at guest pixel x y (800x600 display) via QMP absolute pointer. usage: qclick.py x y"""
import json, os, socket, sys
x, y = int(sys.argv[1]), int(sys.argv[2])
s = socket.socket(socket.AF_UNIX); s.connect(os.path.join(os.path.dirname(os.path.abspath(__file__)), "run", "qmp.sock")); f = s.makefile("r"); f.readline()
def c(m):
    s.sendall(json.dumps(m).encode() + b"\n")
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r: return r
c({"execute": "qmp_capabilities"})
ax, ay = int(x * 32767 / 800), int(y * 32767 / 600)
ev = lambda d: c({"execute": "input-send-event", "arguments": {"events": d}})
ev([{"type": "abs", "data": {"axis": "x", "value": ax}}, {"type": "abs", "data": {"axis": "y", "value": ay}}])
ev([{"type": "btn", "data": {"button": "left", "down": True}}]); ev([{"type": "btn", "data": {"button": "left", "down": False}}])
print("clicked", x, y)
