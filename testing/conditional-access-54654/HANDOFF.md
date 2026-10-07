# Handoff: fleetdm/fleet#54654 lab (PingFederate and Duo guides)

Read this first when resuming. It is the clean, current picture: what the project is, where everything is, what is done and open, and how to work safely. Last updated 2026-10-07 evening (UTC+2 local).

## The project
Test the PingFederate and Duo conditional-access guides and scripts in [fleetdm/fleet#54346](https://github.com/fleetdm/fleet/pull/54346) for [issue #54654](https://github.com/fleetdm/fleet/issues/54654) (Noah Talerman). Fix what's broken, propose guide edits, ship the guides. Owner: Adam Baali (Fleet CSA). Only the lab Fleet `https://fleet.mpc.ad` (Premium) may be changed.

## Where everything is
**Review outside Claude (GitHub, public lab repo):** https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/conditional-access-54654
| What | Path (under that folder) |
| --- | --- |
| **Linux test report** (start here) | `test-evidence/linux/REPORT.md` |
| Per-test evidence (raw output, VM screenshots) | `test-evidence/linux/<ID>-*/` (`result.md` in each) |
| Configuration as tested (sanitized) | `test-evidence/linux/CFG-configuration-as-tested/` |
| Duo Admin Panel records | `test-evidence/linux/_duo-admin-records/` |
| macOS renewal watcher log | `test-evidence/renewal/watch.log` |
| Every test in order, all platforms | `RESULTS.md` |
| Status / resume steps | `STATUS.md` |
| Untested items and what to run next | `NOTES.md` |
| PingFederate UI validation results | `VALIDATION.md` |
| Proposed guide and script fixes (diff) | `fleet-54654-fixes.diff` |
| Test cases | `TEST_PLAN.md` |
| Setup scripts, tests | `ping/`, `stepca/`, `duo/`, `linux-vm/`, `tests/` |

**On this Mac (`/Users/adam/Downloads/fleet-54654-lab/`):** the same files plus what is never published: `.env`, `secrets/`, `vm/` (disk images, ISOs), `stepca/data`, `evidence/_private/` (uncropped screenshots with the lab's public IP), `fleet/` (PR checkout; fixes are 12 local commits on branch `adam/ping-duo-fixes`, not pushed), `ISSUE_UPDATE.md` (draft comment for the issue, not posted), `evidence/*.sh` (scripts that produced the evidence; `evidence/lib.sh` has the helpers).

**GitOps repo (applies to the lab Fleet on every push to `main`):** `AdamBaali/fleet.mpc.ad-gitops`: fleet "Ping Duo Lab", policies, profiles, `LAB_CA`, and `.github/workflows/duo-sync.yml` + `duo/` (the Duo sync).

## Status (2026-10-07 evening)
- **macOS and Linux tested.** Linux A-to-Z: 22 PASS, 2 PARTIAL (D-1 Duo Desktop only runs on the ARM VM through x86 emulation; D-12 day-long sync pending), 0 FAIL. macOS passes P-1, P-9 to P-14, P-16, D-1, D-3 to D-8, L-1.
- **Guide fixes** (all tested except the items listed in `NOTES.md`): Ping Step 6 variable names; `fleetHostID` mapping claim retracted (P-6b); Client Auth Port required; macOS `AllowAllAppsAccess` (Chrome/Firefox still prompt once); Linux import script fixes; browser auto-select needs the cert-request port; export script temp files + shrink guard; Duo script keys as secrets (keyless script), secret name `DUO_FLEET_API_TOKEN`.
- **Running:** `duo/sync-loop.sh` (D-12; stop by deleting `duo/sync.run`), `evidence/renewal/watch.sh` (P-15 macOS), Docker `stepca` + `pingfederate`, Cloudflare tunnel `fleet-lab-scep`, Duo demo `https://ping.lab:8443`, `lab-linux` UTM VM (virtual TPM, Duo Desktop under QEMU 10).
- **Open:** P-15 macOS renewal (a 7-hour certificate that crosses midnight UTC should renew on Fleet's hourly job; not renewed as of 19:22 UTC); D-12 result; enable the Actions `schedule:` after D-12; UI-only (non-GitOps) path checks; Windows (needs an x64 machine: office server request, ticket confidential#17869, Proxmox suggested); Linux EST; L-2; D-7 on Linux. Question for Noah: should the guide say a new host signs in before its first policy run (P-13)?
- **Next PR:** Adam opens a **draft** PR in fleetdm/fleet after the remaining tests and keeps it draft until Windows x64 testing is done.

## Working rules (learned the hard way)
1. **Never print secrets.** Redaction regexes missed twice (the `ping-observer` token and a Duo secret key reached the chat). Use `pbcopy` or pipe straight into `gh secret set`. Don't read the Duo `device_cache_sync.py` files except through a script that never prints them.
2. **Secret names:** the repo secret `FLEET_API_TOKEN` belongs to the GitOps workflow. The Duo token is `DUO_FLEET_API_TOKEN`. Overwriting it broke GitOps for ~3 hours (fixed with a new `gitops-lab` API user).
3. **Only upload what has been run and tested** to the public repo; untested items live in `NOTES.md`. Scan before publishing (the save script `tools/save-to-repo.sh` does; set `NO_PUSH=1` to stage). The public repo's `.gitignore` ignores `evidence/`, so evidence is published as `test-evidence/`.
4. **Don't take full-screen screenshots of the Mac** (it captured Slack once). VM screenshots come from inside the guest (`gnome-screenshot` via `vm/linux/vm-run.sh`).
5. **Things that hang or are blocked here:** `hdiutil attach` and `brew install --cask` (disk image eject); UTM can't read ISOs by path (attach through the UTM UI); `launchd` can't run scripts under `~/Downloads` (macOS privacy protection); the permission classifier blocks bypass-code creation, editing permission settings, and credential-handling edits (ask Adam to do those or add an `autoMode` rule); `~/.claude/projects` is root-owned so Claude memory can't be written.
6. **Adam's preferences:** short messages; do the work yourself instead of handing him commands (except sign-ins, passwords, and permission changes); clean evidence he can review outside Claude; presentable reports.

## Resume checklist
```bash
cd /Users/adam/Downloads/fleet-54654-lab
docker ps                                                  # stepca, pingfederate up?
pgrep -fl 'cloudflared|sync-loop|watch.sh'                 # tunnel, D-12 loop, renewal watcher
tail -3 duo/sync.log; tail -2 evidence/renewal/watch.log   # D-12 health, renewal state
/Applications/UTM.app/Contents/MacOS/utmctl list           # lab-linux running?
```
