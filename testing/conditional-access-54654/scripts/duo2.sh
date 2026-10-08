. evidence/lib.sh
R=AdamBaali/fleet.mpc.ad-gitops
ev_init D-6 "GitHub Actions workflow syncs Fleet hosts to Duo" "A workflow in a GitHub repo (any repo, GitOps or not) runs the export and Duo's keyless sync script using secrets." "Run succeeds; macOS and Linux synced; Windows skipped (no hosts)." >/dev/null
ev_cmd D-6 workflow-file "cat <gitops-repo>/.github/workflows/duo-sync.yml" >/dev/null
ev_cmd D-6 secrets-configured "gh secret list -R $R | awk '{print \$1, \$2, \$3}'" >/dev/null
ev_cmd D-6 run-summary "gh run view 37646267078 -R $R --json databaseId,conclusion,event,createdAt,updatedAt,headSha,jobs -q '{run:.databaseId, conclusion, event, started:.createdAt, finished:.updatedAt, sha:.headSha[0:7], steps:[.jobs[0].steps[]|{n:.number,name:.name,conclusion}]}'" >/dev/null
ev_cmd D-6 raw-log-of-sync-step "TMP=\$(mktemp -d); gh api repos/$R/actions/runs/37646267078/logs > \$TMP/l.zip 2>/dev/null; unzip -p \$TMP/l.zip 'sync/5_*' | sed -E 's/^[0-9T:.Z-]+ //' | grep -v -E '^\\s*\$|DUO_.*_(MKEY|IKEY|SKEY):|FLEET_API_TOKEN:|DUO_API_HOST:|##\\[' | cut -c1-170; rm -rf \$TMP" >/dev/null
ev_verdict D-6 PASS "Run 37646267078 on main of the public lab repo: the keyless duo/device_cache_sync.py plus ten repo secrets synced macOS (1 device) and Linux (1 device) and skipped Windows (no hosts). Works from any repo; the earlier base64-script-secret idea was replaced because only the keys are secret."
# D-9
ev_init D-9 "Export failures leave the previous files alone" "If a Fleet request fails, or a list would shrink by more than half, the export exits non-zero and does not replace the CSVs Duo is fed." "Non-zero exit, no temp folder left behind, previous files unchanged; FORCE=true overrides the shrink guard." >/dev/null
SETUP="W=\$(mktemp -d); sed -e 's#https://fleet.example.com#https://fleet.mpc.ad#' -e 's#<Windows-MachineGuid-report-ID>#69#' fleet/docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh > \$W/export.sh; cd \$W; printf 'device_id\\nOLD-1\\nOLD-2\\n' > macos.csv; printf 'device_id\\nOLD-W1\\n' > windows.csv; printf 'device_id\\nOLD-L1\\n' > linux.csv"
ev_cmd D-9 bad-report-id "$SETUP; sed -i '' 's#reports/\$WINDOWS_REPORT_ID#reports/999999#' export.sh; FLEET_API_TOKEN=\$FLEET_TOKEN_DUO bash export.sh; echo \"exit code: \$?\"; echo '--- files after the failed run (should still be the OLD ones, no .duo-export folder):'; ls -A; head -3 macos.csv" >/dev/null
ev_cmd D-9 invalid-token "$SETUP; FLEET_API_TOKEN=not-a-real-token bash export.sh; echo \"exit code: \$?\"; echo '--- files after (unchanged):'; ls -A; cat linux.csv" >/dev/null
ev_cmd D-9 shrink-guard "$SETUP; (echo device_id; seq 1 300) > windows.csv; FLEET_API_TOKEN=\$FLEET_TOKEN_DUO bash export.sh; echo \"exit code: \$?\"; echo \"windows.csv still has \$(( \$(wc -l < windows.csv) - 1 )) rows (300 before, live Fleet has 0 Windows hosts)\"; echo; echo '--- same run with FORCE=true:'; FORCE=true FLEET_API_TOKEN=\$FLEET_TOKEN_DUO bash export.sh | tail -4; echo \"windows.csv now has \$(( \$(wc -l < windows.csv) - 1 )) rows\"" >/dev/null
ev_cmd D-9 test-harness-fixed-script "bash tests/test_export_script.sh fleet/docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh 2>&1 | tail -32" >/dev/null
ev_cmd D-9 test-harness-original-script "git -C fleet show pr-54346:docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh > /tmp/export-original.sh; bash tests/test_export_script.sh /tmp/export-original.sh 2>&1 | grep -E 'FAIL|failed|All checks' ; unlink /tmp/export-original.sh" >/dev/null
ev_verdict D-9 PASS "Bad report ID and invalid token both exit non-zero and leave the previous CSVs untouched with no temp folder; the shrink guard refuses a 300-to-0 drop and FORCE=true overrides it. The 27-check harness passes on the fixed script; the original PR script fails 6 of the new checks."
# D-10
ev_init D-10 "Duo's script refuses an empty list" "A header-only CSV (for example when a Fleet token sees no hosts) must not wipe Duo's trusted list." "Duo's sync script refuses and exits non-zero; nothing is activated." >/dev/null
ev_cmd D-10 header-only-csv "python3 - <<'P'
import re,os,subprocess
t=open('secrets/duo/linux/device_cache_sync.py').read()
blk=re.search(r\"MKEY_CREDENTIALS = \\{\\n.*?\\n\\}\\n\",t,re.S).group(0)
env=dict(os.environ,DUO_MKEY=re.search(r\"'(DM[A-Z0-9]{18})'\",blk).group(1),DUO_IKEY=re.search(r\"'API_IKEY'\\s*:\\s*'([^']+)'\",blk).group(1),DUO_SKEY=re.search(r\"'API_SKEY'\\s*:\\s*'([^']+)'\",blk).group(1),DUO_API_HOST=re.search(r\"'API_HOST'\\s*:\\s*'([^']+)'\",blk).group(1))
open('/tmp/empty-ev.csv','w').write('device_id\n')
r=subprocess.run(['.venv/bin/python','<gitops-repo>/duo/device_cache_sync.py','--infile','/tmp/empty-ev.csv','--device_id_column','device_id','--dry_run'],env=env,capture_output=True,text=True)
o=(r.stdout+r.stderr)
for k in ('DUO_SKEY','DUO_IKEY','DUO_MKEY'): o=o.replace(env[k],'<'+k.lower()+'>')
print('(header-only CSV, --dry_run)'); print(o); print('exit code',r.returncode)
P" >/dev/null
ev_verdict D-10 PASS "Duo's script refuses a header-only CSV (no device IDs read) and exits 1, so an empty Fleet export cannot wipe the list. Consequence: the last host cannot be removed by an empty list (see the Duo guide note)."
# D-12
ev_init D-12 "Five-minute sync running for hours" "The 5-minute sync runs without Duo API errors or rate limits." "No FAILED lines; runs about every 5 minutes." >/dev/null
ev_cmd D-12 sync-log-stats "python3 - <<'P'
import re,datetime as d
L=[l.strip() for l in open('duo/sync.log') if l.strip()]
runs=sorted({l.split()[0] for l in L})
ts=[d.datetime.strptime(r,'%Y-%m-%dT%H:%M:%SZ') for r in runs]
gaps=[(b-a).total_seconds() for a,b in zip(ts,ts[1:])]
print('first run :',runs[0]); print('last run  :',runs[-1]); print('distinct run timestamps:',len(runs))
print('median gap between runs: %.0f s, max gap: %.0f s'%(sorted(gaps)[len(gaps)//2],max(gaps)))
print('FAILED lines:',sum('FAILED' in l for l in L))
print('synced lines: macos',sum(' macos: 1 synced' in l for l in L),'| linux',sum(' linux: 1 synced' in l for l in L),'| windows skipped',sum('windows: no hosts' in l for l in L))
P; echo; echo 'last 6 log lines:'; tail -6 duo/sync.log" >/dev/null
