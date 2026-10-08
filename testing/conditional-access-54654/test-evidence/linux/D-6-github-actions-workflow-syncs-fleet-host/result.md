# D-6: GitHub Actions workflow syncs Fleet hosts to Duo

- **Started:** 2026-10-07T18:44:47Z
- **Objective:** A workflow in a GitHub repo (any repo, GitOps or not) runs the export and Duo's keyless sync script using secrets.
- **Expected:** Run succeeds; macOS and Linux synced; Windows skipped (no hosts).

## Steps and evidence
- `01-workflow-file.txt`: `cat <gitops-repo>/.github/workflows/duo-sync.yml`
- `02-secrets-configured.txt`: `gh secret list -R AdamBaali/fleet.mpc.ad-gitops | awk '{print $1, $2, $3}'`
- `03-run-summary.txt`: `gh run view 37646267078 -R AdamBaali/fleet.mpc.ad-gitops --json databaseId,conclusion,event,createdAt,updatedA`
- `04-raw-log-of-sync-step.txt`: `TMP=$(mktemp -d); gh api repos/AdamBaali/fleet.mpc.ad-gitops/actions/runs/37646267078/logs > $TMP/l.zip 2>/dev`

## Result: **PASS**

Run 37646267078 on main of the public lab repo: the keyless duo/device_cache_sync.py plus ten repo secrets synced macOS (1 device) and Linux (1 device) and skipped Windows (no hosts). Works from any repo; the earlier base64-script-secret idea was replaced because only the keys are secret.

_Finished 2026-10-07T18:44:49Z_

- `05-terminal-actions-runs-and-secrets.png`: gh run list for the Duo sync workflow and the secret names (Terminal window capture on the Mac, added 2026-10-08). Six manual runs succeeded; two scheduled runs (02:02 and 08:50 UTC) also succeeded; secret names only, no values.
