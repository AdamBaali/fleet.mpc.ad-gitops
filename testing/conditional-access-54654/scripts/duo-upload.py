"""usage: duo-upload.py <macos|windows|linux> <csv> [--dry_run]
Runs the keyless Duo sync script for one integration, taking its credentials from the downloaded Duo script in secrets/.
Prints Duo's output with every credential masked."""
import re,os,subprocess,sys
os_,csv=sys.argv[1],sys.argv[2]; extra=sys.argv[3:]
t=open(f'secrets/duo/{os_}/device_cache_sync.py').read()
blk=re.search(r"MKEY_CREDENTIALS = \{\n.*?\n\}\n",t,re.S).group(0)
env=dict(os.environ,
 DUO_MKEY=re.search(r"'(DM[A-Z0-9]{18})'",blk).group(1),
 DUO_IKEY=re.search(r"'API_IKEY'\s*:\s*'([^']+)'",blk).group(1),
 DUO_SKEY=re.search(r"'API_SKEY'\s*:\s*'([^']+)'",blk).group(1),
 DUO_API_HOST=re.search(r"'API_HOST'\s*:\s*'([^']+)'",blk).group(1))
r=subprocess.run(['.venv/bin/python','~/Documents/GitHub/fleet.mpc.ad-gitops/duo/device_cache_sync.py','--infile',csv,'--device_id_column','device_id']+extra,env=env,capture_output=True,text=True)
o=r.stdout+r.stderr
for k,m in (('DUO_SKEY','<skey>'),('DUO_IKEY','<ikey>'),('DUO_MKEY','<integration-key-id>')): o=o.replace(env[k],m)
print(o); print('exit code',r.returncode)
