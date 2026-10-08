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

## GitHub Actions schedule for the Duo sync (2026-10-08): reliability and cost
- **Observed:** with `cron: "2-59/5 * * * *"` on `main` from 22:12 UTC, the first scheduled run came at 02:02 UTC and the second at 08:50 UTC (2 runs in about 11 hours; the local loop did 235 cycles in the same period). GitHub's docs say schedules can be delayed or dropped under load, run only on the default branch, and (public repos) switch off after 60 days without activity.
- **Fleet's own repo** only schedules daily or 6-hourly jobs, off the top of the hour, never every 5 minutes (`fleet/.github/workflows`).
- **Cost:** a 5-minute run is about 288 runs a day. Each is billed as at least 1 minute, so a private repository on the free plan (2,000 minutes a month) would use it up in about 7 days. Public repositories are free.
- **Options for the guide:** (1) an external scheduler (cron on a server, Cloudflare Worker, cron-job.org) calling `workflow_dispatch` with a fine-grained token (Actions write, one repo): reliable clock, extra secret; (2) keep a GitHub schedule but set expectations of 15 to 60 minutes of lag and say it is best effort; (3) the lab's workaround: a half-hourly schedule whose run loops every 5 minutes for 28 minutes. It keeps a 5-to-10-minute cadence but uses about 28 runner minutes per half hour (public repos only); (4) run the sync from a server or VM the customer already has (the local loop in this lab).
- **Lab change (not yet tested):** `duo-sync.yml` now uses `cron: "3,33 * * * *"` and loops for 28 minutes. To test: push, watch 3 or more scheduled runs, record start times and the gaps between syncs.

## 2026-10-08: scope decision
Adam decided the export script improvements (temp files, 50% shrink guard, `FORCE=true`) are out of scope for the PR. The commit is reverted on `adam/ping-duo-fixes` (`547fd977c9`) and the guide no longer describes them. The tests (D-9, D-10) and the lab's own copy of the script keep the safeguards as evidence; the idea stays here as an option for a later change.

## 2026-10-08: sync interval decision
Adam chose to keep the guide simple and follow Duo's recommendation (daily sync, see duo.com/docs/trusted-endpoints-generic-duo-desktop). The Duo guide and the lab workflow now run once a day (`17 6 * * *`); the half-hourly loop idea is dropped. The 5-minute local loop stays as D-12 evidence only. Trade-off: a newly enrolled host can wait up to a day for its first sign-in unless someone runs the workflow by hand.

## 2026-10-08 (later): sync interval, final decision
Adam wants the guide to keep the quick sync (a daily sync is too slow for a new host). The Duo guide is back to every 5 minutes with a short note on GitHub's limits (best effort, about 8,600 minutes a month) and the server option. The lab workflow goes back to `2-59/5 * * * *`.
