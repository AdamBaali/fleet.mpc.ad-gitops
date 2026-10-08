# Handoff: fleetdm/fleet#54654 lab (PingFederate and Duo guides)

**Read this first when resuming.** It is the clean, current picture: the project, where everything is, what is done and open, what is running, how to work safely, and exactly what to do next. Last updated 2026-10-08 00:20 UTC (see the "Update" block right below).

## Update 2026-10-08 11:00 UTC (newest: everything but Windows is done and written up)
- **Done and documented:** macOS and Linux with pictures (`evidence/linux`, `evidence/macos`, `evidence/console`), `RESULTS.md`, `STATUS.md`, `GUIDE-FINDINGS.md` (public repo copy) and the draft issue comment `ISSUE_UPDATE.md` (lab folder only, **not posted**; do not post to fleetdm/fleet until Adam says). P-15 renewal is closed (behaviour seen twice, documented); no more renewal tracking.
- **Adam still has to:** push the local commits in GitHub Desktop (`a294c77`, `a6f3947`, `3375e20`) and commit `duo-sync.yml` (half-hourly schedule, 5-minute loop, untested). Then watch 3 scheduled runs (`gh run list --workflow duo-sync.yml`).
- **Screenshot tooling:** `tools/screens/macterm.sh <png> <script>` opens a NEW Terminal window, captures only it, closes only it. `winid`, `maskbox` as before. Never close windows you did not open.
- **lab-linux VM** had stopped on its own around 09:50 UTC; restarted with `utmctl start lab-linux`. Check `utmctl list` first when resuming.
- **Still open:** Windows x64 (hardware), the draft PR (12 local commits on `adam/ping-duo-fixes`; the new findings are not yet in those commits), UI-only path, Linux EST/L-2/D-7, teardown, Dependabot alert. The `ping-observer` token appeared in one screenshot I viewed (masked in saved files); rotate at teardown.

## Update 2026-10-08 11:10 UTC (macOS Duo pictures done)
- Added `evidence/macos/D-5-duo-trusted-endpoint-sign-in` and `evidence/macos/D-8-duo-blocks-mac-with-failing-critical-policy` (window-only; IP, location, codes masked). D-8 uploaded a placeholder list for the Mac by hand (`evidence/duo-upload.py macos <csv>`); the lab loop runs with `REQUIRE_PASSING_CRITICAL_POLICIES` off. The Mac was out of Duo's list for about 5 min and is back (09:04:48 UTC sync). Chrome window was left on the Duo callback page.
- macOS pictures now cover: P-15 renewed sign-in, P-9/P-10 flip, P-14 Safari, P-16 Firefox, D-5, D-8. Not pictured on macOS: P-1/P-2 keychain (text only), D-1 Duo Desktop (menu bar app), D-3/D-4/D-6/D-7/D-12 (command-line, log evidence).

## Update 2026-10-08 11:00 UTC (newest, macOS pictures done)
- **macOS window-only screenshots now exist** in `evidence/macos/` (also `test-evidence/macos/` in the public repo): `P-15-renewed-certificate-chrome-sign-in`, `P-9-10-chrome-critical-policy-flip` (61 s fail, 66 s recover; denied/ok shots), `P-14-safari-sign-in` (picker, keychain prompt "MDM Allow All", deny -> "can't establish a secure connection", allow -> callback ok), `P-16-firefox-sign-in` (OS Client Cert Token, two failed attempts with PingFederate `[X509000] No Client Certificate was presented`, third attempt PASS after quitting Firefox and choosing Always Allow). Firefox was installed by Fleet from FMA `firefox/darwin` (policy automation, 2026-10-07 12:42 UTC).
- **Method (window only):** `/tmp/winid <App>` (build from `tools/screens/winid.swift`) prints the window id, `screencapture -x -o -l<id> file.png`, masks with `/tmp/maskbox file x y w h ...` (`tools/screens/maskbox.swift`, top-left pixels; mask sign-in codes and the Chrome profile area). Only capture when the app has a single window you opened. Keystrokes via osascript are blocked, so Adam must click dialogs. `evidence/macflip.sh fail|pass` flips the Mac's critical policy.
- **Skipped:** Keychain Access window (list never populated in a window capture and the login keychain holds personal items) and a Duo Desktop window (menu bar app). Keychain proof stays text: `evidence/renewal/certinfo.py` output.
- **Guide findings:** each browser needs a one-time keychain "Always Allow" for the SCEP key even with `AllowAllAppsAccess`; a denied prompt looks like "Authentication failed" (no certificate); Firefox must be restarted after a wrong answer.
- **Unpushed commits** in the public repo (local): `529b526`, `703ea1c`, `95156ef` (macOS evidence) and `29b8141` if not yet pushed: Adam pushes via GitHub Desktop.
- **Still open:** Fleet and Duo console pages (pane tabs need Adam's sign-in; my tools cannot save pane screenshots, so text evidence only); PingFederate admin (pane refuses localhost https); Windows x64; draft PR; GitHub schedule unreliable (1 run in 10 h).

## Update 2026-10-08 08:20 UTC
- **P-15 macOS renewal PASSED, unattended, twice:** `A8EAEE31` renewed at 00:39 UTC (29 min after the window opened) to `F0F14345`, which renewed at 05:38 to `F7313E7E` (expires 2026-10-09 10:09:40 UTC). One identity in the keychain every time. Next renewal expected about 10:38 UTC. Details in `RESULTS.md` ("P-15 macOS certificate renewal"), logs in `evidence/renewal/{watch,overnight}.log`. Still open: a Chrome sign-in with a renewed certificate (needs a visible Chrome window; do when Adam is at the Mac).
- **GitHub schedule:** fired once (02:02 UTC, success), about 4 h after it reached `main`, and only 1 run since. Not reliable for a 5-minute sync. Local loop: 235 cycles, 0 failed.
- The overnight watcher exited at the renewal; `watch.sh` and `sync-loop.sh` still run.

## Update 2026-10-08 00:20 UTC (older, superseded where it conflicts)
- **Overnight watcher is running:** `evidence/renewal/overnight.sh` (under `caffeinate`) logs every 5 min to `evidence/renewal/overnight.log` and exits when the Mac certificate serial changes (baseline `A8EAEE3123AB6DC21B5F51A9AC816738`) or after 9 h (about 09:12 UTC). Also running: `watch.sh`, `duo/sync-loop.sh` (133 cycles, 0 failures), Docker `stepca` + `pingfederate`, tunnel, UTM `lab-linux`. Keep the Mac plugged in, awake, online. First thing: `tail -20 evidence/renewal/overnight.log`.
- **P-15 macOS renewal:** Fleet's window opened 00:09:51 UTC. Not renewed yet at 00:12. Nothing queued on host 12. Fleet's hourly job runs on Render (not readable with `fleetctl`). If it never renews: check `fleetctl api /hosts/12/activities/upcoming`, the Fleet error store, and whether the profile's cert validity of 2 days is below Fleet's 2-day minimum.
- **GitHub schedule did not fire:** `duo-sync.yml` has `schedule: cron "2-59/5 * * * *"` on `main` (commit `c20a80e`, pushed about 22:12 UTC). Actions enabled, workflow active, yet no run with `event=schedule` after 2 h. Investigate in the morning (try a different minute pattern, `*/10`, check the Actions tab banner, repo activity). The local loop keeps D-12 going.
- **Picture evidence (user asked "stop missing things"):** Linux pictures now exist for D-5 (7), D-8 (5), P-14 (6), P-9, P-10, P-7, P-8, P-11 (2), D-1, L-1, P-3. Repo commits: `0abc1c5` (P-7, P-8) is pushed; `3a9369f` (P-11, D-1, L-1, P-3) is **committed locally in the public repo, not pushed: Adam pushes it from GitHub Desktop**. Method: `evidence/lib.sh` `ev_shot` (VM screenshot), terminal shots via `/tmp/term.sh <cmdfile>` in the VM (gnome-terminal, saved in `tools/screens/`), one-time sign-in codes masked with a small CoreGraphics swift tool (build `tools/screens/mask2.swift` with `swiftc`: black boxes over the URL bar x380-730,y88-110 and body text x340-665,y129-151).
- **Still has NO pictures:** Linux P-4, P-5, P-6, P-6b, P-12, P-13, D-3, D-4, D-6, D-9, D-10, D-12, P-15; ALL macOS tests (Safari, Chrome, Firefox sign-in, keychain certificate, Duo Desktop window, policy flip); console pages (Fleet host page, PingFederate admin data store and policy contract, Duo Admin Trusted Endpoints). Adam's pasted GitHub Actions screenshot of the Duo sync runs is not saved (it shows his browser profile; ask before adding to D-6). Rules: never capture the whole Mac screen (a past shot caught Slack); use app-window captures only, VM shots from inside the guest. Fleet and Duo admin sign-ins need Adam once in the browser pane.
- **Findings from this session:** `/sys/class/dmi/id/product_uuid` is root-only on Ubuntu (Duo Desktop runs as root so it still reads it); `liststores.sh` helper prints "0 x" because its grep misses the nickname (the certificates are there per `certutil -L`); Chromium with no policy shows the picker, Cancel gives `access_denied` "Authentication failed" (P-11 picture).
- **Auto mode classifier blocks:** pushing to the public repo, running `save-to-repo.sh` (reads `.env` for the scan), and copying files that could hold credentials. Workaround that is accepted: Adam pushes through GitHub Desktop; I only `git add` and `git commit` locally.
- **Origin/main** also has Adam's own commits (deleted `docs/flock-to-fedora` and `articles` directories, edits to `duo-sync.yml`). Pull before any local work; do not fight those deletions.

## The project
Test the PingFederate and Duo conditional-access guides and scripts in [fleetdm/fleet#54346](https://github.com/fleetdm/fleet/pull/54346) for [issue #54654](https://github.com/fleetdm/fleet/issues/54654) (Noah Talerman). Fix what's broken, propose guide edits, ship the guides. Owner: Adam Baali (Fleet CSA). Only the lab Fleet `https://fleet.mpc.ad` (Premium) may be changed.

## Where everything is
**GitHub (public lab repo; review outside Claude):** https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/conditional-access-54654
| What | Path (under that folder) |
| --- | --- |
| **Linux test report** (start here) | `test-evidence/linux/REPORT.md` (22 pass, 2 partial, 0 fail) |
| Per-test evidence (raw output, VM screenshots) | `test-evidence/linux/<ID>-*/result.md` |
| Configuration as tested (sanitized) | `test-evidence/linux/CFG-configuration-as-tested/` |
| Duo Admin Panel records | `test-evidence/linux/_duo-admin-records/` |
| macOS renewal watcher log | `test-evidence/renewal/watch.log` |
| All tests in order, all platforms | `RESULTS.md` |
| Untested items, repo hygiene, next runs | `NOTES.md` |
| Test matrix and status | `STATUS.md` |
| PingFederate UI validation | `VALIDATION.md` |
| Proposed guide/script fixes | `fleet-54654-fixes.diff` |
| Test cases | `TEST_PLAN.md` |
The GitOps repo itself (applies to the lab Fleet): `.github/workflows/workflow.yml` (apply), `.github/workflows/duo-sync.yml` + `duo/` (Duo sync), `fleets/ping-duo-lab.yml`, `docs/flock-to-fedora/CONTEXT.md` (moved out of the root).

**On this Mac (`/Users/adam/Downloads/fleet-54654-lab/`):** the same files plus what is never published: `.env`, `secrets/`, `vm/` (disk images, ISOs; `lab-windows` is a stuck ARM VM, safe to delete), `stepca/data`, `evidence/_private/` (uncropped screenshots with the lab's public IP; fleet error dump), `fleet/` (PR checkout; the fixes are 12 local commits on branch `adam/ping-duo-fixes` off `pr-54346`, **not pushed**), `ISSUE_UPDATE.md` (draft issue comment, not posted), `evidence/*.sh` + `lib.sh` (scripts that produced the evidence), `tools/save-to-repo.sh` (scan + commit + push the public repo; `NO_PUSH=1` to stage).

## Status
- **Tested:** macOS and Linux. Linux A-to-Z: 22 PASS, 2 PARTIAL (D-1 Duo Desktop runs on the ARM VM only through x86 emulation; D-12 day-long sync pending), 0 FAIL. macOS: P-1, P-9 to P-14, P-16, D-1, D-3 to D-8, L-1 pass. D-6 (Actions workflow) passes.
- **Guide fixes (tested unless listed in `NOTES.md`):** Ping Step 6 variable names; "map `fleetHostID`" claim retracted (P-6b); Client Auth Port required; macOS `AllowAllAppsAccess` (Chrome/Firefox still prompt once); Linux import script fixes; browser auto-select must use the cert-request port (9032); export script temp files + 50% shrink guard; Duo keys as secrets with a keyless script; Duo token secret is `DUO_FLEET_API_TOKEN`.
- **GitOps repo (cleaned up 2026-10-07):** workflows pinned to `ubuntu-24.04` (`ubuntu-latest` becomes Ubuntu 26 on **2026-10-19**: test before moving), `checkout@v6`/`setup-python@v6` (no warnings), live apply skipped for pushes that only touch `testing/`, `duo/`, markdown or `duo-sync.yml`. Last apply green. Open: Dependabot high alert `apache/thrift` in `extensions/windows_yellowkey/go.mod` (fix 0.24.0), untouched.
- **Incident to know about:** from 15:42 to 18:58 UTC the GitOps applies failed because I overwrote the repo secret `FLEET_API_TOKEN` with the Duo token. Fixed with a new `gitops-lab` API user (gitops role) and the separate `DUO_FLEET_API_TOKEN` secret. Failed runs left in history on purpose.

## Running right now (leave them on; keep the Mac awake and online)
| Process | What for | Stop with |
| --- | --- | --- |
| `duo/sync-loop.sh` (under `caffeinate -i`) | D-12: Duo sync every 5 min, log `duo/sync.log`, 0 failures so far (started 12:48 UTC) | `rm duo/sync.run` |
| `evidence/renewal/watch.sh` | P-15 macOS: logs the lab certificate every 5 min to `evidence/renewal/watch.log` | `rm evidence/renewal/watch.run` |
| Docker `stepca`, `pingfederate`; `cloudflared` tunnel `fleet-lab-scep` | the lab CA (SCEP lifetime set to 1710 min, restore to 2160h), PingFederate, the SCEP tunnel | `docker compose down` in `stepca/` and `ping/`; kill cloudflared |
| UTM VM `lab-linux` | Linux host (virtual TPM; Duo Desktop under QEMU 10 emulation) | `utmctl stop lab-linux` |
| Duo demo on `https://ping.lab:8443` (127.0.0.1 and the VM bridge) | sign-in target | `duo/start-demo.sh stop` |

## Next steps (in order)
1. **P-15 macOS renewal (after about 01:10 UTC on 2026-10-08).** The Mac holds certificate serial `A8EAEE3123AB6DC21B5F51A9AC816738` (issued 2026-10-07 19:38:51 UTC, expires 2026-10-09 00:09:51 UTC, `DATEDIFF`=2). Fleet's renewal window opens at **00:09 UTC on Oct 8**; its hourly job should renew by about 01:10 UTC. An earlier 7-hour certificate never renewed because Fleet counts whole days. Check:
   ```bash
   cd /Users/adam/Downloads/fleet-54654-lab
   python3 evidence/renewal/certinfo.py ~/Library/Keychains/login.keychain-db   # new serial? how many identities?
   tail -6 evidence/renewal/watch.log
   fleetctl api -F per_page=8 -F order_key=created_at -F order_direction=desc /activities | jq -r '.activities[]|"\(.created_at[0:19]) \(.type)"'
   ```
   Record: new serial and `notBefore`, identity count (old one replaced or left behind?), a Chrome sign-in (`state=macchrome...` flow), then add a section to `RESULTS.md`/`NOTES.md` and run `tools/save-to-repo.sh`. The server's "Renewing MDM managed certificates" log line is on Render (not readable with `fleetctl`).
2. **D-12 result:** `python3 evidence/syncstats.py` (cycles, median gap, failed lines), update `D-12-*/result.md`, regenerate `python3 evidence/mkreport.py`.
3. **Turn on the Actions schedule:** stop the local loop (`rm duo/sync.run`), add `schedule: - cron: "2-59/5 * * * *"` to `duo-sync.yml` in the GitOps repo, push, watch 3 scheduled runs.
4. **UI-only (non-GitOps) path:** check through the API on a scratch fleet: custom SCEP CA, profile with `$FLEET_VAR_*` and `$FLEET_SECRET_*`, critical policy, report with keep-data and interval, Duo scheduling without GitOps.
5. **Open the draft PR** in fleetdm/fleet with the 12 local commits on `adam/ping-duo-fixes` (Adam does this; keep it draft until Windows x64 testing is done). Post `ISSUE_UPDATE.md` as the issue comment (Adam posts it).
6. **Windows:** blocked on an x64 test machine (office server request, internal ticket; Proxmox suggested). Duo Desktop for Windows is Intel-only. The ARM VM `lab-windows` is stuck in recovery and can be deleted.
7. **Still untested:** Linux EST path, L-2 (no product UUID), D-7 on Linux, Fleet-driven Duo Desktop install on Linux, whether the TPM mattered for Duo on Linux.
8. **Question for Noah:** should the guide say a brand-new host signs in before its first policy run (P-13 passes)?

## Teardown (when finished)
Stop the processes above; restore step-ca `fleet-scep` lifetime to 2160h; delete Fleet users `ping-observer`, `duo-observer` (keep `gitops-lab`; the old `Claude` admin API user is unused); delete Fleet host records; deactivate the Duo Linux/macOS integrations and delete user `lab-test`; remove `127.0.0.1 ping.lab` from `/etc/hosts`; remove the lab MDM profile and the Chrome auto-select profile from the Mac; delete the UTM VMs; rotate the Ping DevOps key and the Duo Web SDK secret and macOS integration secret key (all appeared in chat once).

## Working rules (learned the hard way)
1. **Never print secrets.** Redaction regexes missed twice. Use `pbcopy` or pipe straight into `gh secret set`. Don't read the Duo `device_cache_sync.py` files except through a script that prints nothing (`evidence/duo-upload.py`).
2. **Secret names:** `FLEET_API_TOKEN` is the GitOps workflow's; the Duo one is `DUO_FLEET_API_TOKEN`.
3. **Only upload what has been run and tested** to the public repo; untested items go in `NOTES.md`. Scan first (`tools/save-to-repo.sh`). Adam authorised pushes only to `AdamBaali/fleet.mpc.ad-gitops`; never push to fleetdm/fleet or comment on its issues. The public repo's `.gitignore` ignores `evidence/`, so evidence is published as `test-evidence/`.
4. **No full-screen screenshots of the Mac** (once captured Slack). VM screenshots come from inside the guest.
5. **Hangs or blocked here:** `hdiutil attach` and `brew install --cask` (disk-image eject); UTM can't read ISOs by path; `launchd` can't run scripts under `~/Downloads`; the permission classifier blocks creating bypass codes, editing permission settings, and credential-handling edits; `vm/linux/vm-run.sh` has a ~40 s limit; `sed -i` on macOS needs `''`.
6. **Adam's preferences:** short messages; do the work yourself except sign-ins, passwords and permission changes; evidence he can review outside Claude; check with him before anything is posted publicly.
