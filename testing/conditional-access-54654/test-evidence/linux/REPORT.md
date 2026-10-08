# Conditional access guides (PingFederate and Duo): Linux test report

Test of the guides and scripts in [fleetdm/fleet#54346](https://github.com/fleetdm/fleet/pull/54346) for [#54654](https://github.com/fleetdm/fleet/issues/54654). Linux run from scratch on 2026-10-07, with evidence for every test.

| | |
|---|---|
| **Lab Fleet** | Fleet 4.92.3 Premium (`fleet.mpc.ad`), fleet "Ping Duo Lab", everything applied through GitOps |
| **PingFederate** | 13.1.3 in Docker, X.509 Certificate IdP Adapter 1.3.2, secondary HTTPS port 9032 |
| **CA** | Smallstep step-ca 0.30.2 with a SCEP provisioner behind a Cloudflare Tunnel (used by the Mac); Linux certificates issued directly |
| **Duo** | Trial account, three Generic Trusted Endpoints integrations (Linux and macOS active for group `fleet-lab`), Web SDK demo app |
| **Linux host** | Ubuntu 24.04 arm64 VM (UTM), Firefox 157 (deb and snap), Chromium 154 (snap), fleetd, Duo Desktop 4.7.0 (x86-64 package under emulation, see caveats) |
| **Evidence** | Per-test folders below: raw command output with timestamps, screenshots taken inside the VM, sanitized configuration. Tokens, keys and the lab's public IP are redacted. |

**Result: 22 passed, 2 partial, 0 failed.**

## Results

| ID | Test | Result | What it showed | Evidence |
|---|---|---|---|---|
| P-5 | Fleet REST data store connection | **PASS** | PingFederate Test Connection returned HTTP 200; with the Observer-only token Fleet returned the host UUID, host ID and failing_critical_policies_count. | [P-5…](P-5-fleet-rest-data-store-connection/result.md) |
| P-3 | Linux certificate import into browser stores | **PASS** | The fixed script imports into all four stores (Chrome NSS, deb Firefox, snap Firefox, snap Chromium) and a rerun leaves one certificate per store. The original PR script missed the deb Firefox profile (~/.config/mozilla/firefox)… | [P-3…](P-3-linux-certificate-import-into-browser-st/result.md) |
| P-4 | Linux: users added later and Firefox profiles created later | **PASS** | Confirmed: a user created later only gets the Chrome store when the script runs, and a Firefox profile created after the import stays empty until the script is run again. Guide note added (rerun after Firefox first opens and for… | [P-4…](P-4-linux-users-added-later-and-firefox-prof/result.md) |
| P-6 | Lookup variable names in the authentication policy | **PASS** | PingFederate accepts only ad.<adapter ID>.<attribute> and ds.<source ID>.<attribute> names (it lists the available keys in its log). The guide wording ${hostUUID} and ${fleetHostID} gives Unknown Key; a criterion with value… | [P-6…](P-6-lookup-variable-names-in-the-authenticat/result.md) |
| P-6b | fleetHostID does not need to be mapped | **PASS** | With fleetHostID removed from the policy contract and not mapped, the second lookup still resolved ${ds.fleetByUuid.fleetHostID}, sign-in succeeded and the log had 0 WARN/ERROR lines. The earlier claim that it must be mapped was… | [P-…](P-6b-fleethostid-does-not-need-to-be-mapped/result.md) |
| P-7 | Managed host passing its critical policies can sign in | **PASS** | Critical policy passing (failing_critical_policies_count 0); the VM signed in with its certificate and PingFederate returned an authorization code. | [P-7…](P-7-managed-host-passing-its-critical-polici/result.md) |
| P-8 | Failing a non-critical policy does not block sign-in | **PASS** | The non-critical policy 'CA test - always fails (non-critical)' is failing on the host and sign-in still succeeded. | [P-8…](P-8-failing-a-non-critical-policy-does-not-b/result.md) |
| P-9 | Failing a critical policy denies sign-in | **PASS** | Creating the flag file and selecting Refetch: Fleet showed failing_critical_policies_count 1 after 160 seconds. Sign-in was then denied with error=access_denied and the message Host is not in Fleet or is failing a critical policy. | [P-9…](P-9-failing-a-critical-policy-denies-sign-in/result.md) |
| P-10 | Fixing the critical policy restores sign-in | **PASS** | Removing the flag file and selecting Refetch: Fleet showed failing_critical_policies_count 0 after 146 seconds. The next sign-in returned an authorization code. | [P-10…](P-10-fixing-the-critical-policy-restores-sign/result.md) |
| P-11 | No certificate: sign-in is denied | **PASS** | Without a client certificate PingFederate redirects with error=access_denied and the message Authentication failed. | [P-11…](P-11-no-certificate-sign-in-is-denied/result.md) |
| P-12 | Valid certificate for a host that is not in Fleet is denied cleanly | **PASS** | A valid lab-CA certificate for a UUID that Fleet does not have gets a clean access_denied redirect (not a server error page). PingFederate logs a warning for the Fleet 404. | [P-12…](P-12-valid-certificate-for-a-host-that-is-not/result.md) |
| P-13 | A new host signs in before its first policy run | **PASS** | Deleting the host made fleetd re-enroll it within 8 seconds (new host id 13, policy responses empty). A sign-in right away returned an authorization code and failing_critical_policies_count was 0, so unrun policies do not block.… | [P-13…](P-13-a-new-host-signs-in-before-its-first-pol/result.md) |
| P-14 | Skipping the certificate picker in Chromium and Firefox on Linux | **PASS** | Chromium (snap) shows the Select a certificate picker with no policy and with a policy for the wrong port (9031); AutoSelectCertificateForUrls for https://ping.lab:9032 with an issuer filter skips the picker and reaches the… | [P-14…](P-14-skipping-the-certificate-picker-in-chrom/result.md) |
| P-15 | Linux: certificate renewal replaces the old certificate | **PASS** | Rerunning the import script after a new certificate was issued replaced the old one in every store (serial 6B49... to 333D...), one entry per store, and sign-in worked with the new certificate. Fleet does not renew Linux… | [P-15…](P-15-linux-certificate-renewal-replaces-the-o/result.md) |
| D-1 | Duo Desktop for Linux installed and running | **PARTIAL** | Duo Desktop 4.7.0 (amd64 package from Duo's download link) is installed and its service is active, answering on HTTPS 53100 and HTTP 53106. It needed lab workarounds because the VM is ARM: amd64 multiarch, x86 libraries, QEMU 10… | [D-1…](D-1-duo-desktop-for-linux-installed-and-runn/result.md) |
| D-3 | Export script writes the three CSVs | **PASS** | The export (guide script plus temp-file and shrink-guard fix) wrote macos.csv and linux.csv with one UUID each and header-only windows.csv; no temp folder was left behind. | [D-3…](D-3-export-script-writes-the-three-csvs/result.md) |
| D-4 | Duo sync uploads the Linux list | **PASS** | The keyless script created a cache, uploaded the Linux UUID and (in dry-run) discarded it; the 5-minute loop shows real runs with 'linux: 1 synced'. The script holds no keys; they come from environment variables. | [D-4…](D-4-duo-sync-uploads-the-linux-list/result.md) |
| D-5 | Linux host: Duo trusts it and sign-in succeeds | **PASS** | From the Linux VM (Firefox 157 plus Duo Desktop 4.7.0 under emulation) the sign-in to the Duo demo ended with trusted_endpoint_status trusted, auth_result allow (Login Successful), device_info_source duo_desktop, endpoint… | [D-5…](D-5-linux-host-duo-trusts-it-and-sign-in-suc/result.md) |
| L-1 | Linux device ID: Duo Desktop, Fleet and the CSV agree | **PASS** | product_uuid = Fleet host UUID = linux.csv row = 86d7dc8e-3373-47af-86dd-56a1cd517e2f, and Duo marked the endpoint trusted. Case matched (lowercase). The /etc/machine-id fallback is not used because this VM exposes a product… | [L-1…](L-1-linux-device-id-duo-desktop-fleet-and-th/result.md) |
| D-6 | GitHub Actions workflow syncs Fleet hosts to Duo | **PASS** | Run 37646267078 on main of the public lab repo: the keyless duo/device_cache_sync.py plus ten repo secrets synced macOS (1 device) and Linux (1 device) and skipped Windows (no hosts). Works from any repo; the earlier… | [D-6…](D-6-github-actions-workflow-syncs-fleet-host/result.md) |
| D-8 | Linux host removed from Duo's list is blocked | **PASS** | With this Linux VM removed from the list Duo holds (a placeholder ID kept the list non-empty), the same sign-in as D-5 was stopped at Device not allowed (Event ID AXYXQ8VGBFW9YPOLHDRP; Duo log 18:50:58 Denied, Endpoint is not… | [D-8…](D-8-linux-host-removed-from-duos-list-is-blo/result.md) |
| D-9 | Export failures leave the previous files alone | **PASS** | Bad report ID and invalid token both exit non-zero and leave the previous CSVs untouched with no temp folder; the shrink guard refuses a 300-to-0 drop and FORCE=true overrides it. The 27-check harness passes on the fixed script;… | [D-9…](D-9-export-failures-leave-the-previous-files/result.md) |
| D-10 | Duo's script refuses an empty list | **PASS** | Duo's script refuses a header-only CSV (no device IDs read) and exits 1, so an empty Fleet export cannot wipe the list. Consequence: the last host cannot be removed by an empty list (see the Duo guide note). | [D-10…](D-10-duos-script-refuses-an-empty-list/result.md) |
| D-12 | Five-minute sync running for hours | **PARTIAL** | Snapshot: about 70 sync cycles over six hours, median gap 300 s, no FAILED lines and no Duo API errors or rate limits. The full day will be recorded tomorrow. | [D-12…](D-12-five-minute-sync-running-for-hours/result.md) |

_Configuration as tested: [CFG-configuration-as-tested](CFG-configuration-as-tested/result.md). Environment: [00-environment-and-configuration](00-environment-and-configuration/result.md)._

## What this changed in the guides

| Finding | Proven by | Guide change |
|---|---|---|
| Lookup paths accept only `${ad.<adapter ID>.<attribute>}` and `${ds.<source ID>.<attribute>}`; `${hostUUID}` and `${fleetHostID}` are "Unknown Key"; a criterion value is compared as literal text | P-6 | Ping Step 6 |
| `fleetHostID` does **not** need to be mapped to the policy contract (an earlier finding said it did; retracted) | P-6b | Step removed from Ping Step 6 |
| Import script missed Mozilla's apt Firefox and the snap Chromium store; reruns needed for new users and new Firefox profiles | P-3, P-4 | Script fix + Ping Step 3 (Linux) note |
| Browser auto-select must name the host and port that request the certificate (9032), not the sign-in URL port; Firefox needs its own policy | P-14 | Ping "Skip the certificate picker" |
| Linux certificates are not renewed by Fleet; rerunning the import script replaces the old one | P-15 | Ping Step 3 (Linux) note |
| A brand-new host signs in before its first policy run | P-13 | Open question for the team (no guide change yet) |
| Fleet noticed a policy change 146 to 160 s after Refetch in this run (35 to 70 s earlier in the day) | P-9, P-10 | Guide wording "about a minute" is optimistic |
| Export script could leave empty or truncated CSVs; Duo refuses an empty list | D-9, D-10 | Export script fix (temp files, 50% shrink guard, `FORCE`) |
| Duo's script holds its keys; keep only the keys as secrets and commit a keyless copy | D-4, D-6 | Duo Step 5 (workflow + secrets) |
| Duo Desktop only runs on x86-64 Linux; browser asks for local-network permission | D-1, D-5 | Duo prerequisites and troubleshooting |

## Lab workarounds and limits (read before quoting a result)

- **Duo Desktop on Linux ran under emulation.** Duo supports x86-64 Linux only. The lab VM is ARM, so the x86-64 package runs through QEMU 10 user-mode emulation with `DOTNET_EnableWriteXorExecute=0`, a loader link, x86 libraries and a virtual TPM. This is a lab trick, not a supported setup. D-1 is PARTIAL because of it.
- **Duo Desktop log shows "Error loading computer key" and sends unsigned health data** even with the virtual TPM. Duo still marked the endpoint trusted. Whether the TPM matters was not tested in isolation.
- **The second factor was a bypass code**, because the test user's only enrolled factor is Touch ID on the Mac.
- **Sign-ins were made by curl from inside the VM** (a real client with the host's certificate, same requests a browser makes) and by Firefox and Chromium for the browser tests.
- **Chromium** needed `--ozone-platform=wayland` in this VM and trust for the lab CA in its certificate store. **Firefox** needed a crash-prompt setting because the harness kills it between cases.
- **One Fleet host, one Linux VM.** The "critical policy drops the host from Duo's list" chain needs a second healthy host; D-8 shows the Duo half by replacing the list.
- **The 5-minute sync (D-12) is a snapshot**; the day-long result is recorded tomorrow.
- **PingFederate findings are for version 13.1.3 with one adapter configuration.** Other versions or contexts may name things differently.

## Not run on Linux

- **L-2** (a VM without a product UUID, Duo Desktop 4.7.0 falls back to `/etc/machine-id`): not tested.
- **D-7** (new host appears after the next sync): shown on macOS (see `RESULTS.md`); on Linux the host kept its UUID after re-enrolling, so the list did not change.
- **Fleet-driven Duo Desktop install on Linux** (custom package + policy automation): installed by hand with `dpkg`.
- **Fleet's EST/Hydrant certificate flow for Linux:** step-ca does not do EST, so certificates were issued directly.
- **P-1, P-2, P-16, D-2, D-11:** macOS and Windows tests; see `RESULTS.md` for macOS. Windows is blocked on x64 hardware.

## Related evidence

- macOS results and the renewal test: [`RESULTS.md`](../../RESULTS.md) and [`renewal/`](../renewal/) (a watcher logs the macOS certificate every 5 minutes; a 7-hour certificate that crosses midnight UTC should renew on Fleet's hourly job).
- Duo Admin Panel records: [`_duo-admin-records/`](_duo-admin-records/).
- Tests are re-runnable: [`evidence/*.sh`](../) are the scripts that produced this folder.

_Generated 2026-10-08 09:57 UTC from `results.tsv` and each test's `result.md`._
