# Status and handoff: fleetdm/fleet#54654 lab (as of 2026-10-07 21:30 UTC; see HANDOFF.md for next steps)

Detail for every test is in `RESULTS.md`. `VALIDATION.md` holds the PingFederate UI checks. The plan is `TEST_PLAN.md`. The guide and script fixes are in `fleet-54654-fixes.diff` (12 local commits on branch `adam/ping-duo-fixes` off `pr-54346`, not pushed).

## Where we are
macOS and Linux are tested. Windows is blocked: Duo Desktop for Windows supports Intel only, and the lab Mac can only run Windows on ARM. An x64 test machine is requested.

## Test matrix
| ID | macOS | Linux | Windows |
| --- | --- | --- | --- |
| P-1 / P-2 certificate profile | pass | n/a (manual cert) | not run |
| P-3 / P-4 Linux import | n/a | pass, with script fixes | n/a |
| P-5 / P-6 data store, `${fleetHostID}` | pass (names differ from the guide) | pass | not run |
| P-7 to P-13 sign-in decisions | pass | pass | not run |
| P-14 browser auto-select | Safari asks, Chrome profile pass, Firefox picker | Chromium and Firefox pass | not run |
| P-15 renewal | running (28.5 h cert A8EA..., renewal window opens 00:09 UTC Oct 8; check after 01:10 UTC) | script replace pass | not run |
| P-16 Firefox with OS certificate | pass | n/a | not run |
| D-1 Duo Desktop install via Fleet | pass | manual `dpkg -i` under x86 emulation (works; Fleet-driven install not tested) | blocked (Intel only) |
| D-2 MachineGuid report | n/a | n/a | not run |
| D-3, D-4 export and sync | pass | pass | not run |
| D-5, L-1 trusted / not trusted | pass | pass (trusted via Duo Desktop under emulation, ID = product_uuid) | not run |
| D-6 GitHub Actions workflow | pass (run 37646267078: macOS and Linux synced, Windows skipped; keyless script plus secrets; schedule not enabled yet) | pass | not run |
| D-7 new host appears after sync | pass | | not run |
| D-8 critical policy drops the host | pass at the Duo level (full chain needs a second host) | sync level pass | not run |
| D-9, D-10 export failures | pass | pass | |
| D-11 `report_cap` | n/a | n/a | not run |
| D-12 5-minute sync for a day | running (`duo/sync-loop.sh`, log `duo/sync.log`) | | |
| L-2 no product UUID | | inconclusive | |

## Running now
- `duo/sync-loop.sh` (D-12), started 2026-10-07 about 15:00 local. Stop it by deleting `duo/sync.run`.
- step-ca `fleet-scep` lifetime is 1710 min for the P-15 test. Restore to 2160 h at teardown (backup of `ca.json` in the scratchpad).
- Lab services: `stepca`, `pingfederate` (Docker), Cloudflare tunnel `fleet-lab-scep`, Duo demo on `https://ping.lab:8443`, callback listener on 8765.
- The `lab-windows` UTM VM (Windows 11 ARM) installed, then stuck in recovery after a forced stop. Optional for the PingFederate-only Windows tests.

## Open decisions and blockers
- Windows x64 test machine (request open). Preferred: an office box running Proxmox, with the lab services moved onto it.
- D-6 needs a private GitHub repo name and the Duo scripts as base64 secrets (Adam adds them).
- Noah: should the guide say a brand-new host signs in before its first policy run (P-13)?
- Idea for a feature request: push device changes to Duo's Device API when Fleet hosts change, instead of polling.

## Teardown (when done)
Stop `stepca`, `pingfederate`, the tunnel and the sync loop. Delete the `ping-observer` and `duo-observer` Fleet users and host records. Deactivate the Duo integrations and delete the `lab-test` user. Remove `127.0.0.1 ping.lab` from `/etc/hosts`. Remove the lab MDM profile and the Chrome auto-select profile from the Mac. Restore the step-ca lifetime. Delete the UTM VMs. Rotate the Ping DevOps key and the Duo Web SDK secret, which appeared in chat.

## Not in the repo (keep the lab folder)
`.env`, `secrets/`, `vm/` disk images and ISOs, `stepca/data`, `fleet/` (PR checkout).
