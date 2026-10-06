#!/usr/bin/env bash
# Copy the lab results, scripts and findings into the (public) GitOps repo, scan for credential values,
# then commit and push. Usage: tools/save-to-repo.sh "commit message"   (set NO_PUSH=1 to only stage)
set -euo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"; REPO=/Users/adam/Documents/GitHub/fleet.mpc.ad-gitops
D="$REPO/testing/conditional-access-54654"; cd "$LAB"; mkdir -p "$D"
cp RESULTS.md TEST_PLAN.md STATUS.md "$D/"
for f in ping/docker-compose.yml ping/signin-test.sh ping/host-signin.sh; do cp "$f" "$D/ping/"; done
cp ping/setup/*.sh ping/setup/api_schema.py "$D/ping/setup/"
cp stepca/docker-compose.yml "$D/stepca/"; cp cloudflared/config.yml "$D/cloudflared/"
for f in create-vm.applescript vm-run.sh vm-runf.sh wait-agent.sh run-import.sh run-signin.sh; do cp "vm/linux/$f" "$D/linux-vm/"; done
cp duo/start-demo.sh "$D/duo/"; [ -f duo/sync.sh ] && cp duo/sync.sh "$D/duo/"
cp tests/mock_fleet.py tests/test_export_script.sh "$D/tests/"
[ -f tools/save-to-repo.sh ] && mkdir -p "$D/tools" && cp tools/save-to-repo.sh tools/test-d8-linux.sh "$D/tools/"
# FINDINGS and README live in the repo only (edited there)
python3 - "$D" <<'PY'
import re,os,glob,subprocess,sys
D=sys.argv[1]; secrets={}; allow=set()
for l in open('.env'):
    l=l.strip()
    if '=' in l and not l.startswith('#'):
        k,v=l.split('=',1)
        if re.search(r'KEY|SECRET|TOKEN|PASSWORD|CHALLENGE|ENROLL',k) and len(v)>=8: secrets['env:'+k]=v
secrets['vm-password']=open('secrets/vm-lab-password').read().strip()
for f in glob.glob('secrets/duo/*/device_cache_sync.py'):
    for m in re.finditer(r"""['"]([A-Za-z0-9_\-+/=.]{16,})['"]""",open(f).read()):
        v=m.group(1)
        if (v.startswith('DM') and len(v)==20) or v.startswith('--') or v.startswith('api-'): allow.add(v)
        else: secrets['duo:'+f.split('/')[2]]=v
try:
    pw=subprocess.run(['docker','exec','stepca','cat','/home/step/secrets/password'],capture_output=True,text=True,timeout=20).stdout.strip()
    if pw: secrets['stepca-password']=pw
except Exception: pass
bad=[]
for r,_,fs in os.walk(D):
    for f in fs:
        p=os.path.join(r,f); t=open(p,errors='ignore').read()
        bad+=[(os.path.relpath(p,D),n.split(':')[0]) for n,v in secrets.items() if v in t]
if bad: print("CREDENTIAL HITS, not committing:",bad); sys.exit(1)
print(f"scan clean ({len(secrets)} secret values checked)")
PY
cd "$REPO"; git add testing
if git diff --cached --quiet; then echo "nothing new to save"; exit 0; fi
git commit -q -m "${1:-Update conditional access lab results}

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
[ "${NO_PUSH:-0}" = 1 ] && { echo "committed locally (NO_PUSH)"; exit 0; }
git fetch -q; git merge --ff-only origin/main >/dev/null; git push -q origin main && git log --oneline -1
