#!/usr/bin/env python3 -I
"""GET a Fleet API path using the fleetctl login (token never printed). usage: tools/fleetapi.py /api/latest/fleet/hosts?query=x  -> JSON to stdout"""
import sys,json,os,urllib.request,re
cfg=open(os.path.expanduser('~/.fleet/config')).read()
tok=re.search(r'token:\s*(\S+)',cfg).group(1); addr=re.search(r'address:\s*(\S+)',cfg).group(1).rstrip('/')
r=urllib.request.Request(addr+sys.argv[1],headers={"Authorization":"Bearer "+tok})
print(urllib.request.urlopen(r).read().decode())
