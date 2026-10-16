#!/usr/bin/env python3
"""Tiny QMP client for the QEMU clone. usage:
  vm/qmp.py shot <out.png>        screendump of the guest display
  vm/qmp.py keys <qcode> [...]    send keys one by one, e.g. ret, esc, f8, down, 0..9 (no secrets here)
  vm/qmp.py ps < script.ps1       run PowerShell in the guest via the QEMU guest agent (SYSTEM), print output
"""
import json, os, socket, sys, time

SOCK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "run", "qmp.sock")


def cmd(s, f, execute, arguments=None):
    msg = {"execute": execute}
    if arguments:
        msg["arguments"] = arguments
    s.sendall(json.dumps(msg).encode() + b"\n")
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            return r


def ps():
    import base64
    q = os.path.join(os.path.dirname(SOCK), "qga.sock")
    s = socket.socket(socket.AF_UNIX)
    s.connect(q)
    s.settimeout(120)
    f = s.makefile("r")
    s.sendall(b'{"execute":"guest-sync","arguments":{"id":777}}\n')
    while '777' not in f.readline():
        pass
    script = sys.stdin.read()
    enc = base64.b64encode(script.encode("utf-16-le")).decode()
    pid = cmd(s, f, "guest-exec", {"path": "powershell.exe", "arg": ["-NoProfile", "-EncodedCommand", enc], "capture-output": True})["return"]["pid"]
    end = time.time() + float(os.environ.get("PS_TIMEOUT", "100"))
    while True:
        if time.time() > end:
            print("[timeout: still running in the guest, pid %s]" % pid)
            return
        r = cmd(s, f, "guest-exec-status", {"pid": pid})["return"]
        if r.get("exited"):
            for k in ("out-data", "err-data"):
                if r.get(k):
                    sys.stdout.write(base64.b64decode(r[k]).decode(errors="replace"))
            print("[exit %s]" % r.get("exitcode"))
            return
        time.sleep(1)


def main():
    if sys.argv[1] == "ps":
        return ps()
    s = socket.socket(socket.AF_UNIX)
    s.connect(SOCK)
    f = s.makefile("r")
    f.readline()
    cmd(s, f, "qmp_capabilities")
    if sys.argv[1] == "shot":
        print(cmd(s, f, "screendump", {"filename": os.path.abspath(sys.argv[2]), "format": "png"}))
    elif sys.argv[1] == "keys":
        for k in sys.argv[2:]:
            cmd(s, f, "send-key", {"keys": [{"type": "qcode", "data": k}]})
            time.sleep(0.15)
        print("sent", len(sys.argv) - 2, "keys")


main()
