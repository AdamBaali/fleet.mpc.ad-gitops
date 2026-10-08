import datetime as d
L=[l.strip() for l in open('duo/sync.log') if l.strip()]
runs=sorted({l.split()[0] for l in L})
ts=[d.datetime.strptime(r,'%Y-%m-%dT%H:%M:%SZ') for r in runs]
# the loop logs 3 lines within a second; group lines by minute-of-run
by=sorted({t.replace(second=0) for t in ts})
gaps=[(b-a).total_seconds() for a,b in zip(by,by[1:])]
print('first run :',runs[0]); print('last run  :',runs[-1])
print('sync cycles (distinct minutes):',len(by))
print('median gap between cycles: %.0f s, max gap: %.0f s'%(sorted(gaps)[len(gaps)//2],max(gaps)))
print('FAILED lines:',sum('FAILED' in l for l in L))
print('synced lines: macos',sum(' macos: 1 synced' in l for l in L),'| linux',sum(' linux: 1 synced' in l for l in L),'| windows skipped',sum('windows: no hosts' in l for l in L))
