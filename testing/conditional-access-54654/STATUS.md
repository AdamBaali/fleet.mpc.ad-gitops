# Status: fleetdm/fleet#54654 lab (as of 2026-10-08 10:30 UTC)

Detail for every test is in `RESULTS.md`; evidence with pictures is in `evidence/` (`linux/REPORT.md`, `macos/`, `console/`). The plan is `TEST_PLAN.md`. Guide and script fixes are in `fleet-54654-fixes.diff` (16 local commits (the export-script change was reverted: out of scope) on branch `adam/ping-duo-fixes` off `pr-54346`, not pushed).

## Where we are
macOS and Linux are tested end to end with evidence. **Windows is blocked** on an x64 test machine (Duo Desktop for Windows is Intel only; the lab Mac runs only Windows on ARM). The GitHub schedule fix is written but not tested.

## Test matrix
| ID | macOS | Linux | Windows |
| --- | --- | --- | --- |
| P-1 / P-2 certificate profile | pass | n/a (manual cert) | not run |
| P-3 / P-4 Linux import | n/a | pass, with script fixes | n/a |
| P-5 / P-6 / P-6b data store, variable names | pass (names differ from the guide) | pass | not run |
| P-7 to P-13 sign-in decisions | pass | pass | not run |
| P-14 browser auto-select | Safari picker + keychain prompt, Chrome profile pass, Firefox picker | Chromium and Firefox pass | not run |
| P-15 renewal | **pass**, renewed twice unattended | script replace pass | not run |
| P-16 Firefox with OS certificate | pass (third attempt) | n/a | not run |
| D-1 Duo Desktop install | pass (Fleet-installed) | manual `dpkg -i` under x86 emulation | blocked (Intel only) |
| D-2 MachineGuid report | n/a | n/a | not run |
| D-3, D-4 export and sync | pass | pass | not run |
| D-5, L-1 trusted | pass | pass (ID = product_uuid) | not run |
| D-6 GitHub Actions | partial: works, schedule unreliable | pass | not run |
| D-7 new host appears after sync | pass | not run | not run |
| D-8 blocked when not in the list, recovers | pass at Duo level | pass | not run |
| D-9, D-10 export failures | pass | pass | n/a |
| D-11 `report_cap` | n/a | n/a | not run |
| D-12 5-minute sync for a day | pass (253 cycles, 0 failed) | | |
| L-2 no product UUID | | inconclusive | |

## What the lab did not cover
Sign-in through a SAML or OIDC application (tested with an OAuth client that runs the same authentication policy), a real enterprise CA, a large fleet (`report_cap`), PingFederate clustering, Windows. See `NOTES.md`.

## Running now
Local sync loop (`duo/sync-loop.sh`, stop by deleting `duo/sync.run`; ends the D-12 story), Docker `stepca` and `pingfederate`, the Cloudflare tunnel, UTM `lab-linux`. The certificate watcher is done. step-ca `fleet-scep` lifetime is 1710 min (restore to 2160 h at teardown).

## Open decisions and blockers
- Windows x64 test machine (internal request open; preferred: an office box running Proxmox).
- Push the 12 guide/script commits as a **draft PR** to fleetdm/fleet, and keep it draft until Windows x64 is done (Adam's decision).
- Noah: should the guide say a brand-new host signs in before its first policy run (P-13)?
- Test the half-hourly `duo-sync.yml` schedule after it is pushed.

## Teardown (when done)
Stop `stepca`, `pingfederate`, the tunnel and the sync loop. Delete the `ping-observer` and `duo-observer` Fleet users and host records. Deactivate the Duo integrations and delete the `lab-test` user. Remove `127.0.0.1 ping.lab` from `/etc/hosts`. Remove the lab MDM profile and the Chrome auto-select profile from the Mac. Restore the step-ca lifetime. Delete the UTM VMs. Rotate the Ping DevOps key and the Duo Web SDK secret, which appeared in chat.

## Not in the repo (keep the lab folder)
`.env`, `secrets/`, `vm/` disk images and ISOs, `stepca/data`, `fleet/` (PR checkout).
