# Status and handoff: fleetdm/fleet#54654 lab (as of 2026-10-06, end of day 1)

Resume tomorrow from here. Detail for every test is in `RESULTS.md`; guide edits are in `GUIDE-FINDINGS.md` (repo copy); the plan is `TEST_PLAN.md`. This file is the index.

## Where we are
Phases 0 to 4 are built. Phase 5 (Duo) is set up and half tested. Phase 6 (hosts): Linux done, macOS skipped for now, Windows not started. Phase 7 (all tests) is partly done. Phase 8 (script fixes and guide edits) has not started. Nothing has been sent to Noah or posted on the issue.

## Test matrix
| ID | Status | Notes |
| --- | --- | --- |
| P-1 macOS SCEP profile | not run | profiles are live; no macOS host (UTM can't script the macOS VM wizard; skipped) |
| P-2 Windows SCEP profile | not run | Windows VM is next |
| P-3 Linux import | pass / partial | snap Firefox pass (after rerun), snap Chromium pass (store created by hand), **deb Firefox fails with the guide's script, passes with the patch** |
| P-4 later users / new profiles | confirmed | script must be rerun |
| P-5 data store test | pass | |
| P-6 `${fleetHostID}` | pass, different names | `${ad.<adapter id>.CN}` and `${ds.<source id>.fleetHostID}`; attribute must be mapped |
| P-7 to P-10 sign-in, critical policy, recovery | pass on Linux | recovery about 35 s; not yet on macOS/Windows |
| P-11, P-12, P-13 | pass on Linux | |
| P-14 auto-select | pass | Chromium (port 9032 pattern) and Firefox policy |
| P-15 renewal | pass on Linux (script replaces cert) | Fleet's own 30-day auto-renew not tested |
| P-16 Firefox macOS/Windows | not run | |
| D-1 Duo Desktop install | not run / blocked on Linux | Duo Desktop for Linux is x86-64 only; Mac/Windows not started |
| D-2 MachineGuid report | not run | needs a Windows host |
| D-3 export | pass | |
| L-1 ID match | blocked | needs Duo Desktop |
| L-2 no product UUID | inconclusive | masking in the guest wasn't seen by orbit; needs SMBIOS change |
| D-4 sync | pass (Linux) | macOS/Windows empty |
| D-5 allowed/denied | not run | integrations are disabled on purpose; activate after Duo Desktop hosts exist |
| D-6 GitHub Actions workflow | not run | needs Duo scripts as base64 repo secrets |
| D-7 new host appears | not run | needs the scheduled sync |
| D-8 critical policy flips trust | sync level done on Linux, **gap found** | empty list refused by Duo's script, failing host stays trusted |
| D-9 export failures | pass, leftover | `windows.csv` left empty |
| D-10 empty CSV | done | Duo's script refuses it (exit 1) |
| D-11 `report_cap` | not run | needs Windows hosts |
| D-12 5-minute sync for a day | not run | needs launchd job |

## What is running now
- Docker: `stepca` (CA, port 9000), `pingfederate` (9999 admin, 9031, 9032). PingFederate evaluation licence expires **2026-11-05**.
- Cloudflare tunnel `fleet-lab-scep` → `scep.mpc.ad` (background process; dies on reboot).
- UTM VM `lab-linux` (Ubuntu 24.04 arm64, Fleet host 9, user `lab`) is running.
- Not running: seed web server, Duo demo (needs a VM first; bridge `192.168.64.1` exists only while a VM runs).

## Resume checklist
```bash
cd /Users/adam/Downloads/fleet-54654-lab
docker ps                                   # stepca and pingfederate up? else:
(cd stepca && docker compose --env-file ../.env up -d); (cd ping && docker compose --env-file ../.env up -d)
pgrep -fl cloudflared || (nohup cloudflared tunnel --config cloudflared/config.yml run fleet-lab-scep > cloudflared/tunnel.log 2>&1 &)
curl -s -o /dev/null -w "%{http_code}\n" "https://scep.mpc.ad/scep/fleet-scep?operation=GetCACaps"   # expect 200
/Applications/UTM.app/Contents/MacOS/utmctl list
fleetctl api -F per_page=20 /hosts | jq -r '.hosts[]|"\(.id) \(.platform) \(.status)"'
```
Save progress with `tools/save-to-repo.sh "message"` (copies, scans for credentials, commits, pushes the GitOps repo).

## Fleet and Duo state
- Fleet lab: `https://fleet.mpc.ad`, Premium (20 devices, expires 2027-06-10). Fleet "Ping Duo Lab" (id 4) has 5 policies, the MachineGuid report (id 69), Duo Desktop for macOS/Windows, 4 cert profiles. Everything is applied by the GitOps repo (`AdamBaali/fleet.mpc.ad-gitops`, pushes to `main` apply live). Fleet CA `LAB_CA` and variable `LAB_CA_THUMBPRINT` are declared there.
- Fleet API users: `ping-observer`, `duo-observer` (tokens in `.env`).
- Duo trial account (30 days): 3 Generic Trusted Endpoints integrations (macOS, Windows, Linux), all **disabled**; group `fleet-lab`; user `lab-test` (not enrolled, plan: bypass code); policy "Fleet lab - trusted endpoints only" applied to Web SDK app + `fleet-lab`. Scripts in `secrets/duo/<os>/` (not in git).
- Demo app: `duo/start-demo.sh` (https://ping.lab:8443, needs a VM running).

## Next steps (suggested order)
1. **Windows** (one VM at a time): ISO and UTM guest tools are in `vm/windows/` (Windows 11 ARM 26H2, 8.5 GB). Plan: UTM QEMU VM by script; autounattend with `LabConfig` TPM/Secure Boot bypass (as in UTM's guest-tools `Autounattend.xml`); NVMe disk; drivers from the guest tools ISO; attach ISO and answer files through QEMU extra arguments (UTM can't attach removable media by script; risk: UTM's sandbox may block paths outside its container, so place files inside the VM bundle); send a key at the "press any key" prompt with UTM `input scan code`; fleetd `.msi` is already built in `secrets/packages/`. Then P-2, D-2, D-11, Windows sign-in, Duo.
2. **Duo end-to-end** once Duo Desktop hosts exist: activate each integration for `fleet-lab`, D-5, L-1, D-7, D-8 with several hosts; scheduled sync (`duo/sync.sh` + launchd) for D-12; GitHub Actions workflow with base64 secrets (D-6, Adam adds the secrets).
3. **Linux Duo Desktop**: needs x86-64 (real machine or emulated VM). Decision pending.
4. **macOS host** (optional): manual UTM wizard (IPSW from UTM's own downloader; host is macOS 15, guest must be 15 or older).
5. **Phase 8**: script fixes on a branch off `pr-54346` (one commit per issue): export script temp files and shrink guard (+ tests), import script (XDG Firefox path, create snap Chromium store); then guide edits using `GUIDE-FINDINGS.md`. Show Adam the diff; he decides what goes to Noah. Update the issue (draft text was given in chat).
6. **Teardown** at the end: see CLAUDE.md. Also remove PingFederate diagnostics `ctrlhtml`, `ctrlpcv`, Fleet users, Duo integrations.

## Gotchas learned
- zsh does not split unquoted `$VAR` into words: use bash scripts or arrays.
- `fleetctl api` prefixes `/api/latest/fleet`, takes `-F key=value` before the URL, `fleetctl get reports --fleet` wants the numeric id.
- UTM: `guest size` is ignored for existing images, `source` is ignored for CD drives, `bridge100` exists only while a shared-network VM runs. Linux VM is built by cloud-init over HTTP via an SMBIOS string (`linux-vm/`). `vm-run.sh` / `vm-runf.sh` run commands in the guest.
- Claude Code blocks `rm` inside `docker exec` and `sh -c`; use `unlink` or avoid cleanup in scripted steps. Do not read the Duo scripts' contents (they hold keys).
- Test browsers: GNOME screen lock hid pickers (disabled for `lab`); a picker left waiting times out; Firefox remembers "Don't send a certificate" for a session; first-run welcome page covers the picker.
- Deleting a Fleet host repeatedly can leave orbit crash-looping on 401; stop orbit and remove `/opt/orbit/secret-orbit-node-key.txt`.
- Mac-side screenshots capture Adam's own desktop: use screenshots from inside the guest only.
- `get_page_text` on Duo's Policies page dumps 50 KB; use screenshots there.

## Don't post yet
Only post to the issue or send to Noah what `VALIDATION.md` marks Validated. The PingFederate Step 4 to 6 findings (variable names, criterion, attribute mapping, Client Auth fields) were found through the Admin API and need a check in the PingFederate UI first. The issue comment drafted in chat includes unvalidated items; reword it after validation.

## Open decisions for Adam
- Linux Duo Desktop: skip, emulate x86-64, or use a real x86-64 machine.
- Whether to use a branch + PR for the next pushes to the GitOps repo (pushes to `main` apply live).
- Rotate the Duo Web SDK client secret and the `ping-observer` token (both appeared in chat).

## Not in the repo (keep the lab folder)
`.env`, `secrets/` (Duo scripts, packages, CA material), `vm/` disk images and ISOs, `stepca/data`, `fleet/` (PR checkout).
