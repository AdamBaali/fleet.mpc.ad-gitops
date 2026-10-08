# D-4: Duo sync uploads the Linux list

- **Started:** 2026-10-07T18:43:09Z
- **Objective:** Duo's device_cache_sync.py (keyless copy reading its keys from environment variables) creates a cache, uploads the CSV, and activates it.
- **Expected:** Devices synced: 1.

## Steps and evidence
- `01-sync-script-no-secrets.txt`: `echo 'The script file in the GitOps repo holds no keys:'; grep -c -E "API_SKEY.*[A-Za-z0-9]{30}" ~/D`
- `02-linux-sync-dry-run.txt`: `python3 - <<'P'
import re,os,subprocess
t=open('secrets/duo/linux/device_cache_sync.py').read()
blk=re.search(r"MKEY_CREDENTIALS = \{\n.*?\n\}\n",t,re.S).group(0)
env=dict(os.environ,DUO_MKEY=re.search(r"'(DM[A-Z0-9]{18})'",blk).group(1),DUO_IKEY=re.search(r"'API_IKEY'\s*:
csv='/tmp/linux-ev.csv'; open(csv,'w').write('device_id\n86d7dc8e-3373-47af-86dd-56a1cd517e2f\n')
r=subprocess.run(['.venv/bin/python','<gitops-repo>/duo/device_cache_sync.p
o=(r.stdout+r.stderr)
for k in ('DUO_SKEY','DUO_IKEY','DUO_MKEY'): o=o.replace(env[k],'<'+k.lower()+'>')
print('(--dry_run: uploads the list, then deletes the new cache instead of activating it)'); print(o); print('
P`
- `03-sync-loop-log.txt`: `echo 'Real syncs by the 5-minute loop (duo/sync.log), last 12 lines:'; tail -12 duo/sync.log`

## Result: **PASS**

The keyless script created a cache, uploaded the Linux UUID and (in dry-run) discarded it; the 5-minute loop shows real runs with 'linux: 1 synced'. The script holds no keys; they come from environment variables.

_Finished 2026-10-07T18:43:10Z_

- `04-terminal-duo-sync-dry-run.png`: Duo sync script, Linux list, --dry_run (Terminal window capture on the Mac, added 2026-10-08). 1 device uploaded and the cache replaced; the GitOps copy of the script holds no hard-coded keys (0 lines).
