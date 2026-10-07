# D-10: Duo's script refuses an empty list

- **Started:** 2026-10-07T18:43:56Z
- **Objective:** A header-only CSV (for example when a Fleet token sees no hosts) must not wipe Duo's trusted list.
- **Expected:** Duo's sync script refuses and exits non-zero; nothing is activated.

## Steps and evidence
- `01-header-only-csv.txt`: `python3 - <<'P'
import re,os,subprocess
t=open('secrets/duo/linux/device_cache_sync.py').read()
blk=re.search(r"MKEY_CREDENTIALS = \{\n.*?\n\}\n",t,re.S).group(0)
env=dict(os.environ,DUO_MKEY=re.search(r"'(DM[A-Z0-9]{18})'",blk).group(1),DUO_IKEY=re.search(r"'API_IKEY'\s*:
open('/tmp/empty-ev.csv','w').write('device_id\n')
r=subprocess.run(['.venv/bin/python','/Users/adam/Documents/GitHub/fleet.mpc.ad-gitops/duo/device_cache_sync.p
o=(r.stdout+r.stderr)
for k in ('DUO_SKEY','DUO_IKEY','DUO_MKEY'): o=o.replace(env[k],'<'+k.lower()+'>')
print('(header-only CSV, --dry_run)'); print(o); print('exit code',r.returncode)
P`

## Result: **PASS**

Duo's script refuses a header-only CSV (no device IDs read) and exits 1, so an empty Fleet export cannot wipe the list. Consequence: the last host cannot be removed by an empty list (see the Duo guide note).

_Finished 2026-10-07T18:43:57Z_
