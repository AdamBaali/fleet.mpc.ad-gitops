import re,sys
envp = sys.argv[1]
pubip = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
secrets=[]
for l in open(envp):
    l=l.strip()
    if '=' in l and not l.startswith('#'):
        k,v=l.split('=',1)
        if re.search(r'KEY|SECRET|TOKEN|PASSWORD|CHALLENGE|ENROLL',k) and len(v)>=8: secrets.append(v)
t=sys.stdin.read()
for s in secrets: t=t.replace(s,'<redacted>')
if pubip: t=t.replace(pubip,'<public-ip>')
t=re.sub(r'Bearer [A-Za-z0-9+/=._-]{12,}','Bearer <redacted>',t)
t=re.sub(r'((?:duo_)?code=)[A-Za-z0-9_.~-]{12,}',r'\1<code>',t)
sys.stdout.write(t)
