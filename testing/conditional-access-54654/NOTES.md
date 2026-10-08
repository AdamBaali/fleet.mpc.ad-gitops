# Notes: what is tested, what is not, and what to run next (#54654)

Rule for the public lab repo: upload only what has been run and tested. Everything below that is untested stays
as a note until it has been run.

## Tested and uploaded
- Export script temp files and shrink guard (26 checks plus shellcheck; also run against the live Fleet).
- Linux import script fixes (Ubuntu 24.04: deb Firefox, snap Chromium, snap Firefox, Chrome).
- PingFederate: variable names, Client Auth Port (UI), criteria, sign-in tests on macOS and Linux.
- macOS: SCEP profile, keychain prompts (Safari none; Chrome and Firefox once), Chrome auto-select profile, Firefox.
- Duo on macOS and Linux: export, sync, trusted and not trusted, D-6 workflow (run 37646267078 with the keyless script and secrets).

## In the guide diff but not tested yet (do not treat as proven)
| Item | Where | To test |
| --- | --- | --- |
| Okta Verify Windows `SubjectName` should be `CN=$FLEET_VAR_HOST_UUID,OU=$FLEET_VAR_CERTIFICATE_RENEWAL_ID` | Ping Step 3 (Windows) | Windows host, P-2 |
| `com.microsoft.Edge` payload for Edge auto-select | Ping, skip the picker | An Edge on macOS (dropped for now, Chrome behaves the same) |
| Duo Desktop doesn't support Linux ARM or Windows ARM | Duo prerequisites | From Duo's docs (Windows: "Intel processors only"); Linux ARM from Duo's docs and the arm64 VM that couldn't install it |
| Schedule trigger in the guide's workflow (`cron: "2-59/5 * * * *"`) | Duo Step 5 | Enable on `duo-sync.yml` after D-12 ends, watch a few runs |
| The shrink guard on a fresh Actions checkout | Duo Step 5 | It can't fire (no previous files); the guide says so. A cache step would be needed to make it work |
| Resend a profile from Host details, My device, or the API | Ping troubleshooting | Check the Host details button in the UI (the API was tested) |
| "Hosts that trust the PingFederate server certificate" prerequisite | Ping prerequisites | Lab-only so far (root-trust profile) |
| Fleet doesn't resend an edited SCEP profile to a host with a certificate | Ping troubleshooting | Repeat once on a new host and record the Fleet version |

## Corrected and scoped (2026-10-07 evening)
- **Retracted:** "`fleetHostID` must be mapped." It doesn't need to be (tested: unmapped and removed from the contract, sign-in succeeds, 0 log errors).
- **Confirmed with log text:** `${hostUUID}` and `${fleetHostID}` give `Unknown Key` in a lookup path; `${ad.<adapter ID>.CN}` and `${ds.<source ID>.<attribute>}` work; the criterion value `${hostUUID}` is compared as literal text.
- **Limits:** only one PingFederate configuration was built (version 13.1.3, adapter 1.3.2, adapter ID `x509lab`, policy contract mapping under an authentication policy). Expression-based criteria were not tried, so "can never match" is for plain criteria only. Other versions or contexts (for example an IdP connection's attribute source) may use other names.
- **Client Auth Port:** required on 13.1.3 (the adapter won't save without it); older X.509 kit versions were not checked.

## To run tomorrow (2026-10-08)
1. P-15: after about 14:49 local the macOS certificate should renew by itself (48 h certificate issued about 14:49 on 2026-10-07). Record the new serial, the identity count in the keychain and that sign-in still works.
2. D-12: read `duo/sync.log` for FAILED lines and the count of runs. Then stop the local loop (delete `duo/sync.run`).
3. Enable the Actions schedule (`on: schedule`) and watch 3 runs; this tests the guide's exact `on:` block.
4. UI path via the API on a scratch fleet: custom SCEP CA, profile with `$FLEET_VAR_*` and `$FLEET_SECRET_*`, critical policy, report with keep data and interval.
5. Restore step-ca `fleet-scep` lifetime to 2160 h after P-15 (backup of `ca.json` in the session scratchpad).

## Later (needs hardware or a decision)
- Windows x64 test machine: P-2, D-1, D-2, D-5, D-7, D-8, D-11, L-1 and the Windows sign-in tests.
- Linux: Duo Desktop ran under x86 emulation and passed D-5 and L-1. Still open: a controlled test of whether the TPM matters, D-8 sign-in block on Linux, a Fleet-driven install of the custom package, and Fleet's EST path.
- Noah: should the guide say a new host signs in before its first policy run (P-13)?

## GitOps repo hygiene (2026-10-07)
- **Runner:** GitHub-hosted, now pinned to `ubuntu-24.04` (Ubuntu 24.04.5, image 20261002.596). `ubuntu-latest` moves to Ubuntu 26 on **2026-10-19**. Before moving the pin: run the apply once on `ubuntu-26.04` from a branch and check `fleetctl` installs.
- **Actions:** `checkout@v6`, `setup-python@v6` (the old versions raised a "Node.js 20 is deprecated" warning). Both workflows now run with no annotations.
- **Live apply only when Fleet config changes:** pushes touching only `testing/`, `duo/`, markdown files or `duo-sync.yml` no longer run the apply. Pull requests still dry-run; the nightly 06:00 UTC apply is unchanged.
- **Duo workflow:** `timeout-minutes: 10`; token secret is `DUO_FLEET_API_TOKEN`.
- **History:** 7 failed apply runs from 15:42 to 18:58 UTC on 2026-10-07 were the token mix-up (see RESULTS.md). Left in place on purpose.
- **Still open:** one Dependabot alert (high): `github.com/apache/thrift` in `extensions/windows_yellowkey/go.mod`, fixed in 0.24.0. Not touched.

## 2026-10-08 additions
- GitHub schedule on `duo-sync.yml` has not fired in 2 h (see HANDOFF.md). Cause unknown.
- Picture evidence gaps: see HANDOFF.md "Still has NO pictures".
- `product_uuid` is root-only on Ubuntu; fine for Duo Desktop (root), but a guide check run as a normal user will fail.
- The overnight P-15 watcher log is `evidence/renewal/overnight.log`; add its outcome to RESULTS.md.
