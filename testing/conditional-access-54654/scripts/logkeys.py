import re,sys
for l in sys.stdin:
    l=l.rstrip('\n')
    m=re.search(r'^\S*\s*([\d:,]+)\s',l)
    ts=m.group(1) if m else ''
    u=re.search(r'Unknown Key \(([^)]*)\)',l)
    src=re.search(r'Attribute source id: (\w+)',l)
    if u:
        rest=l.split('substitution with {',1)[-1] if 'substitution with {' in l else ''
        names=sorted(set(re.findall(r'(?:^|, )((?:ad|ds)\.[A-Za-z0-9_.-]+?)=',rest)))
        names=[n for n in names if not n.startswith('ad.x509lab.org.sourceid')]
        print(f"{ts} lookup '{src.group(1) if src else '?'}': Unknown Key ({u.group(1)})")
        print("   keys PingFederate says are available: "+", ".join(names))
    elif 'Comparison Value' in l or 'Actual Value' in l or 'Authorization failed' in l:
        print(f"{ts} {l.split(']',1)[-1].strip()[:200]}" if ']' in l else l[:200])
