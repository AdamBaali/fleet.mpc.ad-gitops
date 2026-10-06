#!/usr/bin/env python3
"""Print the request schema for a PingFederate Admin API endpoint, read from the
server's own OpenAPI spec. Usage: api_schema.py <spec.json> <METHOD> <path> [depth]"""
import json, sys
spec = json.load(open(sys.argv[1]))
method, path = sys.argv[2].lower(), sys.argv[3]
depth = int(sys.argv[4]) if len(sys.argv) > 4 else 2
S = spec["components"]["schemas"]
def name(r): return r.split("/")[-1]
def show(s, d, ind=0, seen=()):
    pad = "  " * ind
    if "$ref" in s:
        n = name(s["$ref"])
        if n in seen or d < 0: print(f"{pad}<{n}>"); return
        sub = S[n]; print(f"{pad}<{n}> required={sub.get('required')}")
        return show(sub, d - 1, ind, seen + (n,))
    t = s.get("type")
    if t == "object" or "properties" in s:
        for k, v in (s.get("properties") or {}).items():
            vt = v.get("type") or name(v.get("$ref", "?")) if "$ref" in v else v.get("type")
            desc = (v.get("description") or "").replace("\n", " ")[:80]
            enum = f" enum={v['enum']}" if "enum" in v else ""
            print(f"{pad}- {k}: {vt}{enum} {desc}")
            if d > 0 and ("$ref" in v or v.get("type") == "array"):
                inner = v.get("items", v) if v.get("type") == "array" else v
                if "$ref" in inner: show(inner, d - 1, ind + 1, seen)
    elif t == "array": show(s["items"], d, ind, seen)
op = spec["paths"][path][method]
body = op.get("requestBody", {}).get("content", {}).get("application/json", {}).get("schema")
print(f"{method.upper()} {path}: {op.get('summary','')}")
if body: show(body, depth)
else: print("(no JSON body)")
