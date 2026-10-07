import re,sys
envp, pubip = sys.argv[1], sys.argv[2]
secrets=[]
for l in open(envp):
    l=l.strip()
    if '=' in l and not l.startswith('#'):
        k,v=l.split('=',1)
        if re.search(r'KEY|SECRET|TOKEN|PASSWORD|CHALLENGE|ENROLL',k) and len(v)>=8: secrets.append(v)
t=sys.stdin.read()
for s in secrets: t=t.replace(s,'<redacted>')
t=t.replace(pubip,'<public-ip>')
t=re.sub(r'Bearer [A-Za-z0-9+/=._-]{12,}','Bearer <redacted>',t)
t=re.sub(r'((?:duo_)?code=)[A-Za-z0-9_.~-]{12,}',r'\1<code>',t)
sys.stdout.write(t)
