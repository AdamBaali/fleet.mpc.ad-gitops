. evidence/lib.sh
R=AdamBaali/fleet.mpc.ad-gitops
ev_init D-6 "GitHub Actions workflow syncs Fleet hosts to Duo" "A workflow in a GitHub repo (any repo, GitOps or not) runs the export and Duo's keyless sync script using secrets." "Run succeeds; macOS and Linux synced; Windows skipped (no hosts)." >/dev/null
ev_cmd D-6 workflow-file "cat <gitops-repo>/.github/workflows/duo-sync.yml" >/dev/null
ev_cmd D-6 secrets-configured "gh secret list -R $R | awk '{print \$1, \$2, \$3}'" >/dev/null
ev_cmd D-6 run-summary "gh run view 37646267078 -R $R --json databaseId,conclusion,event,createdAt,updatedAt,headSha,jobs -q '{run:.databaseId, conclusion, event, started:.createdAt, finished:.updatedAt, sha:.headSha[0:7], steps:[.jobs[0].steps[]|{n:.number,name:.name,conclusion}]}'" >/dev/null
ev_cmd D-6 raw-log-of-sync-step "TMP=\$(mktemp -d); gh api repos/$R/actions/runs/37646267078/logs > \$TMP/l.zip 2>/dev/null; echo 'Lines from the workflow log (secret values are masked by GitHub; env block omitted):'; unzip -p \$TMP/l.zip 0_sync.txt | sed -E 's/^[^ ]*Z //' | grep -E 'csv|total|Starting|Attempting|Uploading|devices uploaded|Activated|Devices synced|skipped|Run bash' | grep -v -E 'DUO_|FLEET_API_TOKEN|MKEY|IKEY|SKEY' | sed -E 's/\x1b\[[0-9;]*m//g' | cut -c1-170; rm -rf \$TMP" >/dev/null
ev_verdict D-6 PASS "Run 37646267078 on main of the public lab repo: the keyless duo/device_cache_sync.py plus ten repo secrets synced macOS (1 device) and Linux (1 device) and skipped Windows (no hosts). Works from any repo; the earlier base64-script-secret idea was replaced because only the keys are secret."
ev_init D-12 "Five-minute sync running for hours" "The 5-minute sync runs without Duo API errors or rate limits." "No FAILED lines; a sync cycle about every 5 minutes." >/dev/null
ev_cmd D-12 sync-log-stats "python3 evidence/syncstats.py; echo; echo 'last 6 log lines:'; tail -6 duo/sync.log" >/dev/null
