# Results: fleetdm/fleet#54654 lab

Lab Fleet: https://fleet.mpc.ad. PR branch: `pr-54346` @ eb703f8ac5.

## Phase 0: setup log

| Date | Item | Result |
| --- | --- | --- |
| 2026-10-06 | Mac RAM | 16 GB, arm64. Under 32 GB, so Ping and Duo tracks run one at a time. |
| 2026-10-06 | Tools | Present: docker 29.6.2 (Docker Desktop, daemon was stopped, started), git, gh, jq, openssl 3.6.2, Python 3.9.6, fleetctl 4.92.1. Installed with brew: shellcheck 0.11.0, step 0.31.0, cloudflared 2026.10.0. |
| 2026-10-06 | duo-client | 5.7.0 in `.venv` |
| 2026-10-06 | DNS | `mpc.ad` is on Cloudflare, so a named tunnel on `scep.mpc.ad` is possible. |
| 2026-10-06 | Fleet license | Adam says Premium. To be confirmed with `fleetctl get config` in Phase 1. |
| 2026-10-06 | `tests/test_export_script.sh` | First run: 16 of 19 checks failed. Cause: the test uses GNU `timeout`, which macOS doesn't have (`timeout: command not found`, exit 127). Test-harness issue, not the guide script. Reran with a throwaway `timeout` shim on PATH (no system install): all 19 pass. `shellcheck` passes on both PR scripts. |

### Notes for later
- The test script needs `timeout`. Worth a `command -v timeout || timeout() { shift; "$@"; }` fallback in `tests/test_export_script.sh` (Phase 8).
- Informational: after a failed report fetch the script leaves `windows.csv` empty (0 lines). This is the truncation risk in the plan (D-9).

## Phase 1: lab Fleet configuration (in progress)

| Date | Item | Result |
| --- | --- | --- |
| 2026-10-06 | Premium license | Confirmed via `GET /config`: tier `premium`, org "Adam Baali - Premium Test Lab", expires 2027-06-10, **device limit 20**. Plan VM count accordingly. |
| 2026-10-06 | fleetctl vs server | Client 4.92.1, server 4.92.3. Version-mismatch warning only. |
| 2026-10-06 | Observer users | `ping-observer` and `duo-observer` created (API-only, global observer). Tokens in `.env`, both verified via `GET /me`. Incident: my redaction regex missed the output format and the `ping-observer` token was printed once in the session transcript. Observer-only, deleted at teardown. |
| 2026-10-06 | Ping package | `vendor/pingfederate-13.1.3/` is the extracted PingFederate server, not a separate X.509 kit. It already ships `server/default/deploy/x509-certificate-adapter-1.3.2.jar` and `legal/X.509_Integration_Kit_Legal.pdf`. Phase 4 step 2 (install kit into `deploy`) may be unnecessary on 13.x. Confirm; possible guide note. |
| 2026-10-06 | Existing Fleet state | Not empty: fleet "Flock to Fedora" (id 3, ~1,060 lines of YAML), 2 offline iOS hosts, labels, Apple push cert. Global (`default.yml`) has no policies or reports. |
| 2026-10-06 | GitOps baseline | `fleetctl generate-gitops` export saved to `secrets/baseline/` (gitignored). Use it as the base so applying `gitops/default.yml` doesn't drop existing global config. Lab hosts will land in the `unassigned` fleet. Don't apply anything for "Flock to Fedora". |

### Lab GitOps repo (found 2026-10-06)

`/Users/adam/Documents/GitHub/fleet.mpc.ad-gitops` (`AdamBaali/fleet.mpc.ad-gitops`, **public**, `main`) is the source of truth for fleet.mpc.ad. Adam authorised changes and pushes there via `gh`, which overrides the "never push" rule in lab CLAUDE.md for that repo only.

- Workflow runs a **real apply on every push to `main` and nightly at 06:00 UTC**; pull requests get dry-run only. `gitops.sh` defaults `FLEET_DELETE_OTHER_FLEETS=true`.
- `default.yml` is thin (`policies:`, `reports:`, `agent_options:` empty; no `certificate_authorities`). A CA added by hand in the Fleet UI (`LAB_CA`) would be removed by the next apply. It has to be declared in the repo, with the challenge from a GitHub secret (repo is public).
- Consequence: don't `fleetctl gitops` from `lab/gitops/` against the live Fleet; the repo's next apply would undo it. Put lab config in the repo, via a branch and PR so CI dry-runs it first.
- `secrets/baseline/` (generate-gitops export) is now only a reference.

### Phase 1 step 4-5 (2026-10-06): lab fleet in the GitOps repo

- Branch `ping-duo-lab` in `fleet.mpc.ad-gitops`, one local commit, **not pushed yet**. Adds `fleets/ping-duo-lab.yml` ("Ping Duo Lab"), `lib/all/policies/ca-test.policies.yml` (2 critical flag-file policies, 1 non-critical always-fail), Duo Desktop install policies (macOS, Windows), `lib/windows/reports/windows-machine-guid.reports.yml`, and the new env line in `workflow.yml`.
- Adam chose: dedicated fleet, push straight to `main` (recommended branch + PR instead; his call).
- Local dry run (`fleetctl gitops -f default.yml -f fleets/flock-to-fedora.yml -f fleets/ping-duo-lab.yml --delete-other-fleets --dry-run`) passed. Dummy values were used for the two existing enroll secrets; a dry run writes nothing.
- Dry run output includes "would've applied certificate authorities": a CA added by hand would be reset. LAB_CA must be declared in `default.yml` (Phase 2).
- Doc gap: `discard_data` (per-report keep-data setting) is not in `yaml-files.md`. The dry run accepted it. Whether it is honoured or ignored is not yet verified; check on the live Fleet after apply.
- Docs note: `install_software` automations only work on a fleet or Unassigned, not global, so a dedicated fleet was needed anyway.

### Phase 1 step 5-6 (2026-10-06): applied and verified

- Pushed `ca83665` to `main` of `fleet.mpc.ad-gitops` (Adam's choice; recommendation was branch + PR). Secret `FLEET_PING_DUO_LAB_ENROLL_SECRET` set by Adam first. Workflow run 37458287395: dry run and real apply both succeeded. Flock to Fedora unchanged (10 policies, 34 reports).
- Live Fleet "Ping Duo Lab" (id 4): 5 policies (2 critical flag-file, 1 non-critical always-fail, Duo Desktop macOS and Windows with `install_software`), report "Windows MachineGuid" (interval 300, `discard_data: false`), software Duo Desktop 7.21.0.0 (darwin) and 7.21.0 (windows).
- `discard_data: false` is the default, so this does not prove the key is honoured. Low risk; recheck only if report rows go missing.
- Software installs on Render (step 6): Fleet downloaded and stored both Duo Desktop packages during the apply, so installer storage works. Still to confirm end to end with a real install on host A or B.
- API note: `fleetctl api` prepends `/api/latest/fleet`, takes `-F key=value` before the URL, and `fleetctl get reports --fleet` wants the numeric ID.
- Duo Web SDK client ID, secret and API host saved in `.env`. Hypervisor: UTM. `LAB_HOST_IP=192.168.64.1` is provisional (UTM shared-network default); verify against the bridge interface once a VM is running.

## Phase 2: step-ca and tunnel (2026-10-06)

| Item | Result |
| --- | --- |
| step-ca | `smallstep/step-ca` 0.30.2 in Docker, `stepca/docker-compose.yml`, data in `stepca/data/` (gitignored). CA "Fleet Lab CA", DNS names localhost, stepca, ping.lab, scep.mpc.ad. Root fingerprint `a0f64e6c...f6d682`. |
| SCEP provisioner | `fleet-scep`: `--type=SCEP --force-cn --include-root --min-public-key-length=2048 --encryption-algorithm-identifier=2`, static challenge from `.env`, RSA 2048 decrypter (`certs/scep_decrypter.crt`, signed by the intermediate), x509 template `stepca/data/templates/scep-client.tpl` (keeps subject, `extKeyUsage: ["clientAuth"]`, `keyEncipherment` + `digitalSignature` for RSA keys). Flags were read from `step ca provisioner add --help`. step-ca embeds the template text in `ca.json`. |
| Finding: cert lifetime | step-ca limits certificates to **24h by default**. `step ca certificate --not-after 8760h` was refused ("more than the authorized maximum certificate duration of 24h1m0s"). SCEP client certs would also expire in 24h. Set `claims` on both provisioners: `admin` default 720h max 8760h, `fleet-scep` default 2160h (90 days) max 8760h. For P-15 renewal tests, expect to lower the default later. Worth a note in the guides if they mention a CA lifetime. |
| Tunnel | Named tunnel `fleet-lab-scep` (id 80c61daa-...), CNAME `scep.mpc.ad`, config `cloudflared/config.yml` (`noTLSVerify` to `https://localhost:9000`, since step-ca's cert is self-signed). Running as a background process (log `cloudflared/tunnel.log`); does not survive a reboot yet. |
| External test | `curl https://scep.mpc.ad/scep/fleet-scep?operation=GetCACert` returns HTTP 200, 1,670 bytes, a PKCS#7 bundle of 3 certs (decrypter, intermediate, root). `GetCACaps`: Renewal, SHA-1, SHA-256, AES, DES3, SCEPStandard, POSTPKIOperation. |
| Fleet CA | Declared as `custom_scep_proxy` `LAB_CA` in the GitOps repo `default.yml` (commit e74465f, local, not yet pushed) with `$FLEET_LAB_CA_SCEP_CHALLENGE`. Local dry run passes. Replaces "Adam adds the CA in the UI" because the repo's apply resets CAs added by hand. Needs the GitHub secret before push. |
| ping.lab cert | `ping/certs/ping.lab.crt` (RSA 2048, SANs ping.lab and localhost, EKU serverAuth + clientAuth, valid 1 year), key mode 600. Chain verifies with `openssl verify`. |
| Fleet CA live | Pushed e74465f to `main` after Adam set `FLEET_LAB_CA_SCEP_CHALLENGE`. Workflow success; `GET /certificate_authorities` shows `LAB_CA` (id 1, `custom_scep_proxy`). Fleet's save-time connection test passed through the tunnel. |

## Phase 3: certificate profiles (2026-10-06)

Pushed a516a3c to `main` of the GitOps repo; workflow success. Live on fleet "Ping Duo Lab": macOS "Lab CA client certificate" (SCEP, `PayloadScope` User) and "Lab CA root certificate" (system trust); Windows `lab-ca-scep-user` (`./User/` paths) and `lab-ca-root-trust` (device root store, `RootCATrustedCertificates/Root/FleetLabCARoot`). Files in the GitOps repo under `lib/macos|windows/configuration-profiles/`. Not yet verified on a host (P-1, P-2).

Choices and guide findings so far:

- **CN, OU:** CN = `$FLEET_VAR_HOST_UUID`, `$FLEET_VAR_CERTIFICATE_RENEWAL_ID` in OU, on both platforms.
- **EKU on macOS:** The Apple SCEP payload has no EKU key. clientAuth comes from the step-ca template. Confirms the suspected issue: Ping guide Step 3 should say the CA sets it, not the profile.
- **Guide issue (Ping, Windows):** The guide points to the Okta Verify profile, whose `SubjectName` is `CN=$FLEET_VAR_HOST_HARDWARE_SERIAL managementAttestation` with no renewal OU. Using it as is gives a serial, not the host UUID. The guide must say to change `SubjectName`.
- **Guide issue (Ping, Windows):** The Okta profile's `EKUMapping` lists four OIDs (document signing, EFS, smart card logon, clientAuth). The lab profile asks only for `1.3.6.1.5.5.7.3.2`. If Windows rejects a certificate that lacks the other EKUs, log it under P-2.
- **Doc inconsistency:** the Wi-Fi article's custom SCEP Windows example uses `KeyLength` 1024 and `SHA-1`; the step-ca provisioner rejects keys under 2048. The lab profile uses 2048 and `SHA-2`. The Okta Verify guide calls `CAThumbprint` "SHA-256" but its sample is 40 hex characters (SHA-1 length), and the Wi-Fi article says SHA1 of the root. The lab uses SHA-1 of the step-ca root (`3AD625AC...0902E1`). Confirm on host B.
- **Guide gap:** neither guide covers trusting the CA root on hosts. The lab added root-trust profiles on both platforms (needed for Safari/Chrome/Edge to accept `ping.lab`).
- **To test (P-15):** Fleet renews about 30 days before expiry (Okta Verify guide). With a ~31-day cert lifetime, renewal triggers a day after issue. Current `fleet-scep` default is 90 days.
- **Not yet tried:** Apple `AllowAllAppsAccess` on the SCEP payload. The guide doesn't mention it. If Chrome or Safari prompt for keychain access to the key, record it and test the key.

Enrollment packages built 2026-10-06 in `secrets/packages/` (gitignored, contain the Ping Duo Lab enroll secret): `fleet-osquery-arm64.msi` (host B), `fleet-osquery_1.61.0_arm64.deb` (host C), macOS `.pkg` (host A). Built with `fleetctl package --fleet-desktop --enable-scripts`.

### Requirement (Adam, 2026-10-06): guides must work for UI users, not only GitOps

Fleet variables (`$FLEET_SECRET_*`) work in both paths: UI at Controls > Variables, GitOps via repo secret plus a `FLEET_SECRET_*` line in the workflow `env` (uploaded each run; never removed by GitOps). Per `secrets-in-scripts-and-configuration-profiles.md`.
- Lab change: Windows SCEP profile now uses `$FLEET_SECRET_LAB_CA_THUMBPRINT` (committed locally in the GitOps repo, **not pushed** until the repo secret exists).
- Guide edits to propose: Ping Step 3 (profiles) show the variable for the thumbprint and both ways to set it. Duo guide Step 6 workflow is GitOps-only; add a UI-user path (run the script on a schedule by cron or a scheduled task, or manually) and say which token it needs.
- Caveat from the secrets guide: a GitOps dry run doesn't fully validate profiles that contain variables, so a green dry run proves little. The real apply and the host result are the tests. Also: secret variables can't be used in Apple `PayloadDisplayName`.
- Still to try in the UI path: create `LAB_CA_THUMBPRINT` via Controls > Variables (or `POST /custom_variables`) on a scratch fleet and upload the profile by hand.
- 2026-10-06: pushed 897aad9 after Adam set `FLEET_SECRET_LAB_CA_THUMBPRINT`. Run succeeded; Fleet now has custom variable `LAB_CA_THUMBPRINT` (id 1), uploaded by GitOps from the repo secret. Windows SCEP profile uses it. Composite actions inherit the step `env`, so only `workflow.yml` needed the new line.

## Phase 4: PingFederate (2026-10-06, in progress)

| Item | Result |
| --- | --- |
| Image | `pingidentity/pingfederate:2609-13.1.3` (arm64), `ping/docker-compose.yml`, named volume `pf_out`, getting-started server profile, DevOps eval license (expires 2026-11-05, 30 days). Admin password in `.env` (`PING_ADMIN_PASSWORD`). |
| X.509 kit | **Not needed on 13.1.3.** The image already contains `x509-certificate-adapter-1.3.2.jar` and the adapter shows in `GET /idp/adapters/descriptors` as "X.509 Certificate IdP Adapter 1.3.2". The guide's prerequisite (kit installed) is still correct for older versions. The vendor zip is the server distribution, not the kit. |
| Secondary port | Default `pf.secondary.https.port=-1`. Set to 9032 with `PF_RUN_PF_SECONDARY_HTTPS_PORT=9032` (from the image's `04-check-variables.sh.pre`). Listening on 9032 after start. |
| Setup scripts | `ping/setup/01-trusted-ca.sh` (root + intermediate), `02-server-cert.sh` (ping.lab PKCS12 import, set as runtime cert; 9031 and 9032 serve the step-ca chain, `openssl s_client` verify OK), `03-fleet-datastore.sh`. Schemas read from the server's own spec: `https://localhost:9999/pf-admin-api/v1/openapi.json`; helper `ping/setup/api_schema.py`. |
| P-5 | **PASS.** REST API data store "Fleet" with `Authorization: Bearer <FLEET_TOKEN_PING>` header and the three attributes. Test Connection action returns "Response code: 200". |
| Guide gap (Step 4) | The X.509 adapter has two settings the guide never mentions: **Client Auth Port** (must be 9032) and **Client Auth Hostname** (ping.lab). |
| Guide gap (Step 5) | The REST data store has a "Base URL" field, a "Base URLs and Tags" table, and "Test Connection URL". Guide only says "Base URL". Tell users to set Test Connection URL (for example `/api/v1/fleet/me`) and run Test Connection. |
| Fleet API shape | `GET /hosts/identifier/:uuid` returns `/host/uuid`, `/host/id`; `GET /hosts/:id/health` returns `/health/failing_critical_policies_count` with an Observer token. Guide's JSON paths are right. |
| Synthetic host (REMOVED) | Adam asked to use a VM instead. Was host id 4, `synthetic-lab-host`, fleet Ping Duo Lab, created with `POST /api/osquery/enroll` using the fleet enroll secret and a random UUID (`secrets/synthetic-uuid`, node key in `secrets/synthetic-node-key`). **Not a real device. Delete at teardown.** |

### Phase 4 status: OAuth sign-in trigger not working yet (2026-10-06) **BLOCKER**

Built via scripts in `ping/setup/` (01 trusted CAs, 02 server cert, 03 Fleet data store, 04 base URL, 05 X.509 adapter `x509lab` with Client Auth Port 9032 / Hostname ping.lab, 06 policy contract `fleetcontract`, 07 auth policy tree, 08 OAuth ATM/APC mapping/client `labclient`). All accepted by the Admin API and read back correctly. `ping/signin-test.sh <cert> <key>` drives `/as/authorization.oauth2` with curl.

Problem: every authorization request fails before any authentication with `There are no authentication methods available for OAuth` (`AuthnAdapterException$NoMappedAdapters`, thrown from `AuthnSourceSupportBase.doLegacySelection`). Tried, all with the same result:
- IdP and SP authentication selection on (docs say OAuth browser flows need the IdP option), and off (legacy path).
- A policy tree (X.509 adapter -> APC mapping) and an APC grant mapping; an IdP adapter grant mapping for `x509lab`; adapter set as default authentication source.
- Container restarts after each change; forcing `pfidpadapterid`.
- **Control:** a standard HTML Form adapter + Simple PCV + IdP adapter grant mapping (`ctrlhtml`, `ctrlpcv`, created by hand, to delete at teardown) fails identically. So it is not the X.509 adapter or the policy; the OAuth server does not see any mapped authentication source.
- DEBUG on `org.sourceid`, `PolicyTreeLogger`, `AuthnSourceSupportBase`: no policy-tree output at all. Log4j2 config restored.

Ideas not yet tried: check the same setup in the admin console (PingFederate UI) to compare; create the OAuth mapping through the UI; enable the IdP role "OAuth" use case checkboxes; try a SAML SP connection instead of OAuth as the trigger.

P-6 (does lookup 2 get `${fleetHostID}` from lookup 1) remains **unanswered**: it needs this flow to run.
Also confirmed from the schemas: attribute source field name is `Resource Path`; the guide's issuance criterion "`fleetHostUUID` equals `${hostUUID}`" is accepted by the API but whether the value is substituted or compared literally is **untested**.

## Duo export script on the live lab Fleet (2026-10-06)

| ID | Result |
| --- | --- |
| D-3 | **PASS** (run with the `duo-observer` token, report id 69 = "Windows MachineGuid", both `REQUIRE_PASSING_CRITICAL_POLICIES` values). Three CSVs, header `device_id`. `macos.csv` has 1 row (the synthetic darwin host), `windows.csv` and `linux.csv` 0 rows (no such hosts). The 2 iOS hosts are excluded from `linux.csv`. Run in `duo/run/` (CSVs gitignored). |

Script weaknesses seen by reading it (to confirm with D-9, D-10, D-11, then fix in Phase 8):
- Each CSV is written straight to its final name (`>macos.csv`), so a failed run leaves a truncated or empty file. The `windows.csv` pipeline fails after truncating it. Confirmed by `tests/test_export_script.sh`: after a failed report fetch `windows.csv` has 0 lines.
- No check that a list shrinks sharply compared with the last run. A zero-host result writes header-only CSVs.
- Linux filter is "not darwin/windows/ios/ipados/android/chrome", so any other platform string counts as Linux.
- Windows hosts depend on the report (limited by `report_cap`, default 1,000 rows).


## Phase 4: sign-in logic, run with a synthetic host then removed (2026-10-06)

Adam asked to use real VMs instead, so the synthetic host (Fleet host 4, fake UUID, made-up policy results) was **deleted** along with its keys. Everything below came from it and is **provisional: rerun on real hosts (A, B, C)**. The PingFederate behaviour findings do not depend on the host and stand.

**Blocker resolved.** The OAuth error "There are no authentication methods available for OAuth" was caused by missing **Access Token Mappings**: the OAuth server only offers an authentication source that has an access token mapping into the client's access token manager. Added `09-access-token-mappings.sh` (one for the X.509 adapter, one for the policy contract). Not in the guide because the guide does not describe the OAuth setup, but anyone testing with an OAuth client will hit it.

| ID | Provisional result (synthetic host, curl driving the real flow with a step-ca client cert) |
| --- | --- |
| P-6 | **Works, but not as the guide writes it.** Lookup 2 sees lookup 1's attributes as `${ds.<source id>.<attribute>}` (here `${ds.fleetByUuid.fleetHostID}`), not `${fleetHostID}`. A plain `${fleetHostID}` is "Unknown Key". |
| P-7 | Sign-in succeeded (authorization code returned), no failing policies. |
| P-8 | Sign-in succeeded with only the non-critical policy failing. |
| P-9 | Denied when the critical policy failed. User sees an OAuth `access_denied` redirect with the criterion's error text. |
| P-10 | After the critical policy passed again, the very next sign-in succeeded. `GET /hosts/:id/health` is read live. Real "within about a minute" timing depends on the host's refetch and must be tested on a real host. |
| P-11 | No client certificate: denied ("Authentication failed"). |
| P-12 | Valid cert for a UUID not in Fleet: clean `access_denied`, not a server error. PingFederate logs an ERROR line for the Fleet 404. |
| P-13 | A host that had never reported policy results signed in successfully: unrun policies are not counted as failing. Guide note stands. |

**Guide findings from this run (PingFederate behaviour, host-independent):**
1. Variable names in lookups: adapter attributes are `${ad.<adapter id>.<attribute>}` (here `${ad.x509lab.CN}`), earlier lookups are `${ds.<source id>.<attribute>}`. The guide's `${hostUUID}` and `${fleetHostID}` are "Unknown Key" in a data store path.
2. ~~A data store attribute is fetched only if something references it; `fleetHostID` must be mapped to a contract attribute.~~ **Wrong, corrected 2026-10-07 (see 'Correction' at the end).** Lookup 2 resolves `${ds.<source id>.fleetHostID}` without any mapping.
3. Issuance criterion "fleetHostUUID equals ${hostUUID}" can never pass: a condition value is literal text (PingFederate logged `Comparison Value: ${hostUUID}`). Expression criteria that could compare two attributes are disabled by default. Fix: drop it. The single criterion "`failingCriticalPolicies` equals `0`" already denies unknown hosts, because lookup 2 cannot resolve and the value is empty (fail closed).
4. The adapter's Client Auth Port and Client Auth Hostname (guide Step 4); the REST data store's Test Connection URL (guide Step 5).
5. Server base URL and virtual host name must be the `ping.lab` name or redirects go to `localhost`.
6. IdP Authentication Policies must be enabled for browser OAuth flows (documented by Ping, not in the guide).
7. step-ca client cert chain: PingFederate had both the root and the intermediate imported as trusted CAs. Not yet tested with only the root; browsers may send only the leaf.

Cleanup still to do: PingFederate objects `ctrlhtml`, `ctrlpcv` (control adapter and validator) and the `x509lab` IdP adapter mapping if unused.

## Host C (Ubuntu 24.04 arm64 in UTM, QEMU) built by script (2026-10-06)

Fleet host 5, `lab-linux`, fleet Ping Duo Lab, UUID = SMBIOS `product_uuid` = UTM VM id (`86d7dc8e-3373-47af-86dd-56a1cd517e2f`). Real device; the synthetic host is gone.

**How it is built (all in `vm/linux/`, gitignored):** Ubuntu official cloud image (sha256 checked) copied to `disk.qcow2`; `create-vm.applescript` makes the VM in UTM (4 GB, 4 CPUs, shared network, virtio GPU, `-smbios type=1,serial=ds=nocloud-net;s=http://192.168.64.1:8000/`); cloud-init `user-data` served from `vm/linux/http/` (python http.server bound to the VM bridge) creates user `lab`, installs `ubuntu-desktop-minimal`, `libnss3-tools`, qemu-guest-agent, trusts the step-ca root, maps `ping.lab` to the host and installs the Fleet `.deb`. `vm-run.sh 'cmd'` runs a command in the guest as root via `utmctl exec` + `file pull`.
Tooling findings:
- UTM scripting cannot attach removable media (`source` ignored for CD drives, `update registry` handles only shared folders) and `guest size` is ignored for an existing image. Worked around by delivering cloud-init over HTTP via SMBIOS and growing the qcow2 header (size + L1 entries; L1 had room) instead of installing qemu-img.
- `bridge100` (192.168.64.1) exists only while a shared-network VM runs; the seed server must start after the VM does. Confirms `LAB_HOST_IP=192.168.64.1`.
- cloud-init installed gdm but did not link `display-manager.service`; GDM stayed off and the console stayed at `tty1` login. Fixed in the seed (`ln -s .../gdm.service /etc/systemd/system/display-manager.service`) and by hand on this VM.
- `/tmp` is cleared on reboot, so the test flag file `/tmp/fleet-ca-test` disappears when the VM restarts (use a persistent path for long tests).
- Claude Code's safety check blocks `rm` inside `docker exec`/`sh -c`; use `unlink` or avoid cleanup in scripted steps.

**Linux certificate (Phase 3.3, P-3, P-4):** Cert issued by hand from step-ca (`step ca certificate`, CN = host UUID, RSA 2048, EKU serverAuth + clientAuth), pushed to `/opt/company/certificate.pem` and `/opt/company/CustomerUserNetworkAccess.key`; `import-certificate-to-browsers.sh` run as root.
- P-3 (partial): **PASS for the NSS database.** `pk12util: PKCS12 IMPORT SUCCESSFUL`; `certutil -L -d sql:/home/lab/.pki/nssdb` lists "Fleet device certificate" (u,u,u) and the step-ca intermediate (from the chain in the PEM). **Firefox untested** (no GUI test yet); `/usr/bin/firefox` exists.
- P-4: **Confirmed.** `lab` had never opened Firefox: no `~/.mozilla/firefox/*` or snap profile existed, so the script imported only into `~/.pki/nssdb` (Chrome/Chromium store). Firefox gets the cert only after it creates a profile and the script is rerun. Users created later also need a rerun. Guide needs a note.

**Sign-in on the real host (curl from inside the VM with its certificate):**
| ID | Result |
| --- | --- |
| P-7, P-8 | **PASS.** Critical policy passing, non-critical "always fails" failing (real osquery results): authorization code returned. |
| P-9 | **PASS.** Flag file created, refetch: Fleet showed `failing_critical_policies_count` 1 after 4 s (first attempt without the same timing took 96 s); sign-in denied (`access_denied`, "Host is not in Fleet or is failing a critical policy"). |
| P-10 | **PASS.** Flag file removed, **Refetch**: count back to 0 after about **35 s**; next sign-in succeeded. Matches the guide's "about a minute". |
| P-6 | **Confirmed on a real host** (the lookups ran with the real UUID and numeric host id). |
P-11, P-12, P-13 rerun on the real Linux host below.

### Firefox on host C (2026-10-06)
Snap Firefox 157 on Ubuntu 24.04. Fleet Desktop had already opened Firefox ("My device"), so a profile existed.
- **P-3 (snap) PASS, with a condition.** The certificate was NOT in the Firefox profile until `import-certificate-to-browsers.sh` was rerun after the profile existed (P-4 again, with a real profile). After the rerun, `certutil -L` on `~/snap/firefox/common/.mozilla/firefox/*.default` shows "Fleet device certificate" (u,u,u) with its key, and the previous entry was replaced, not duplicated. Firefox then showed its certificate picker ("ping.lab has requested that you identify yourself with a certificate", Issued to CN = host UUID, Issued by the step-ca intermediate). After OK, PingFederate sign-in completed (callback `?code=…`).
- **P-14 (Firefox) finding:** Firefox on Linux always asks. The guide only mentions `AutoSelectCertificateForUrls` for Chrome and Edge; Firefox has its own setting (`security.default_personal_cert` = "Select Automatically", set by policy). Add a note.
- **Lab step, not a guide issue:** Firefox did not trust the step-ca root (`Warning: Security Risk` on ping.lab:9031) because it uses its own store. Added the root to the profile with `certutil -A -t CT,,`. In production PingFederate's server certificate normally comes from a CA browsers already trust.
- Method: Firefox opened in the lab user's Wayland session with `snap run firefox --new-tab`; screenshots from inside the guest (`gnome-screenshot`) pulled with `utmctl file pull`; Enter sent with UTM `input scan code`; result confirmed by a callback listener on 127.0.0.1:8765 in the guest. (A first screenshot taken on the Mac captured Adam's own desktop; deleted, no more Mac-side captures.)


### Linux test results on real host C (2026-10-06)

| ID | Result | Evidence |
| --- | --- | --- |
| P-3 snap Firefox | **PASS** (after rerun of the import script, see P-4) | Picker shown, OK, callback `?code=`. |
| P-3 snap Chromium | **PASS** with a caveat | `~/snap/chromium/current/.pki/nssdb` does not exist until Chromium creates it, so the script skips it. I created it with `certutil -N` and reran the script; then the certificate (and key) were present. Same class of gap as P-4. |
| P-3 deb Firefox | **FAIL with the guide's script, PASS with a one-line fix** | Firefox 157.0.1 from Mozilla's apt repo (signing key fingerprint 35BAA0B3...15A3 matches Mozilla's). It keeps its profile in `~/.config/mozilla/firefox/<id>.default-release`, which `import-certificate-to-browsers.sh` never searches (it only looks in `~/.mozilla/firefox`). After the guide's script ran, the profile's store was empty. Adding `"$home"/.config/mozilla/firefox/*/` to the search list imported the certificate and key; Firefox then showed the picker and sign-in succeeded (callback `?code=`). **Script fix needed (Phase 8).** |
| P-4 | **Confirmed (Firefox profile and snap Chromium store)** | Firefox profile created before any import was empty until the script was rerun; the script also skips a Chromium store that does not exist yet. Users created later need a rerun too (not separately tested). |
| P-11 | **PASS** | No client certificate from host C: `access_denied`, "Authentication failed". |
| P-12 | **PASS** | Host deleted in Fleet, valid certificate: `GET /hosts/identifier/<uuid>` is 404; sign-in `access_denied`, "Host is not in Fleet or is failing a critical policy". Clean redirect, no server error page. PingFederate logs an ERROR line for the 404. |
| P-13 | **PASS** | The agent re-enrolled within seconds as a new host (id 5 -> 6, same UUID). Its policies existed but had no result yet; sign-in succeeded, and still did 20 s later (failing count 0). Unrun policies are not counted as failing. Guide note stands: a brand-new host is trusted until its first policy run. |
| P-14 Chromium | **PASS, with a detail the guide lacks** | Baseline: Chromium shows "Select a certificate to authenticate yourself to ping.lab:9032". With `AutoSelectCertificateForUrls` (`/var/snap/chromium/current/policies/managed/*.json`) for `https://ping.lab:9032` and an issuer filter: no picker, sign-in completed. With the pattern for `https://ping.lab:9031` (the sign-in URL): picker returned. The pattern must name the host and port that request the certificate (the adapter's Client Auth host/port). |
| P-14 Firefox | **PASS** with `security.default_personal_cert` = "Select Automatically" | Set through Firefox's enterprise policy file (`/usr/lib/firefox/distribution/policies.json` for the deb): `{"policies":{"Preferences":{"security.default_personal_cert":{"Value":"Select Automatically","Status":"locked"}}}}`. Fresh Firefox start, no click: callback `?code=`. Without it, Firefox always shows the picker. |
| P-15 (Linux) | **PASS** | New cert (new serial) pushed, script rerun: exactly one "Fleet device certificate" in the Chrome store, the Firefox profile and the snap Chromium store, with the new serial; sign-in with the new certificate worked. |
| P-16 | Not applicable here | macOS and Windows only. |

Not run: P-1, P-2 (macOS and Windows hosts), P-16, D-1 to D-12, L-1, L-2. L-1 and L-2 need Duo Desktop on Linux and a Duo trial integration.
New guide notes from this round: Chrome and Edge policy pattern must use the certificate-request host:port; Firefox has its own auto-select setting; the import script skips browser stores that do not exist yet (snap Chromium, new Firefox profiles) so it must be rerun, and the Linux step should say so.


### Linux wrap-up (2026-10-06)
- P-4 for a user created later: `lab2` created after the first import had no certificate store; after a rerun it got `~/.pki/nssdb` with the certificate, but no Firefox profile exists until that user opens Firefox, so Firefox is covered only on a later rerun.
- Test-VM notes: GNOME locked the session after idle and blanked the screen, which hid pickers; disabled for the lab user (`idle-delay 0`, `lock-enabled false`). A first-run "Welcome to Firefox" page covers the picker in a fresh profile; a picker left waiting for tens of seconds times out the connection ("connection has timed out" on ping.lab:9032). Firefox also remembers "Don't send a certificate" for the session, so test with a fresh start.
- **Script fixes queued for Phase 8 (`import-certificate-to-browsers.sh`):** (1) search `~/.config/mozilla/firefox/*/`; (2) create the snap Chromium store (`~/snap/chromium/current/.pki/nssdb`) instead of skipping it; (3) document the rerun requirement (new users, new Firefox profiles).
- Remaining Linux items need Duo: D-1 (Duo Desktop custom package), L-1, L-2, D-7, D-8, D-12.

## Phase 5: Duo (2026-10-06, in progress)

- **Web SDK app:** credentials in `.env` validated: the demo's login POST runs Duo's health check and got a redirect to `https://api-23a45510.duosecurity.com/oauth/v1/authorize` (client id, secret and API host are valid).
- **Demo app:** Duo's `duo_universal_python` demo in `duo/demo/` (gitignored, `duo.conf` holds the secret, mode 600), Flask in `.venv`. Remote use needs an **https** redirect URI with a **hostname, not an IP** (Duo README), so it serves `https://ping.lab:8443/duo-callback` with the step-ca `ping.lab` certificate, bound to the VM bridge (`duo/start-demo.sh`, must start after a VM so `bridge100` exists). The VMs already resolve `ping.lab` to 192.168.64.1 and trust the root.
- **Waiting on Adam in the Duo Admin Panel:** three Generic Trusted Endpoints integrations (macOS, Windows, Linux) with their `device_cache_sync.py` files in `secrets/duo/<os>/`, a test group, a test user, and a policy on the Web SDK app that blocks untrusted endpoints.

### Duo Admin Panel setup (2026-10-06), done in Adam's signed-in Chrome at his request
Trial account "Mountain Path Consulting" (30 days left). Nothing pre-existing was changed.
| Object | Details |
| --- | --- |
| Integrations (Devices > Trusted Endpoints > Add Integration > Generic Integrations) | macOS `DMNV4VV4M97ZYGNW9Z7X` ("Generic with Duo Desktop"), Windows `DM4UDSGRNFPSTGSJ7B69` ("... 1"), Linux `DMLL3RAQIDS2ZW0MJV5R` ("... 2"). All **disabled** for now. Scripts downloaded to `secrets/duo/<os>/device_cache_sync.py` (mode 600), each bound to its own integration key. |
| Group | `fleet-lab` (`DG8N28SBGYSWNSVXRBAW`), manual membership. |
| User | `lab-test` (`DU6OCRC83UV8R21K83AK`, lab-test@mpc.ad), Active, not enrolled, in `fleet-lab`. Plan: use a Duo bypass code for the 2FA step. |
| Policy | "Fleet lab - trusted endpoints only": Trusted Endpoints rule = "Block endpoints that are not trusted". Applied as an **Application-Group policy** to the Web SDK app + group `fleet-lab` only. |
Notes for the guide: the integration page says daily syncs are recommended and shows the API network allow-list empty (open to all networks). The script has `--dry_run` and `--delete_existing_cache` options. The Web SDK app, `adam` user and existing policies were not touched.


### Linux Duo tests (2026-10-06)

**Blocker found: Duo Desktop for Linux is x86-64 only** (per Duo's documentation, ARM is not supported yet; Debian 11/12, Ubuntu 22.04/24.04/26.04, CentOS Stream, RHEL). The Linux test VM on this Apple Silicon Mac is arm64, so Duo Desktop cannot be installed. Blocked on Linux: D-1 (Duo Desktop install), L-1 (ID Duo Desktop reports vs CSV), D-5 (Linux host allowed and denied by Duo). Options: an x86-64 Linux machine, or an emulated x86-64 VM (slow). Guide note: say Linux hosts need x86-64.

| ID | Result |
| --- | --- |
| D-3 | **PASS** on the live lab Fleet with the real Linux host. `linux.csv` has the host's UUID (equal to its DMI product UUID). |
| D-4 (Linux) | **PASS.** `--dry_run`: cache created, 1 device uploaded, cache deleted, "Devices synced: 1". Real run: cache created, 1 uploaded, activated. Count matches the CSV. The integration stays disabled. |
| D-8 (Linux, sync level; script `tools/test-d8-linux.sh`) | **FAIL as designed, important finding.** With `REQUIRE_PASSING_CRITICAL_POLICIES=true` the failing host leaves the CSV (0 rows). Duo's `device_cache_sync.py` **refuses an empty list** (exit 1, "No device IDs read from input column", the new cache is deleted) so the previously active cache, which still contains the failing host, stays. When the failing host is the only host for that OS, trust is never revoked. With two or more hosts the list shrinks and works. After the fix the host returns on the next sync. Fleet showed the change after about 134 s (fail) and 148 s (fix) on a freshly started VM; earlier runs took 4 to 35 s. |
| D-9 | **PASS for exit code, FAIL for leftovers.** Bad report id: export exits 56 (HTTP 404), but `windows.csv` is left **empty with no header** (truncated before the failure). Invalid token: exits 56 (401) before writing anything; the old files are untouched. |
| D-10 | **Duo's script protects against it.** A header-only or empty CSV: the script creates a cache, deletes it, prints "No device IDs read from input column: device_id" and exits 1. The active cache is not replaced. The risk is not an empty upload, it is a partial list (hosts missing because of an API error or a Fleet outage returning fewer rows). The guard in the plan (refuse a drop of more than 50% unless `FORCE=true`) is still needed. |
| L-2 | **Inconclusive.** Fleet reported the same UUID after masking the DMI product UUID and `/etc/machine-id` inside the guest, but the masks were not visible to the `orbit` service (the guest agent runs in its own mount namespace), so nothing was proven. Needs an SMBIOS change on the VM and Duo Desktop. Also learned: deleting a host in Fleet repeatedly while orbit retries can leave orbit crash-looping on `401 ... device_token` (exits instead of re-enrolling); fix by stopping orbit and removing `/opt/orbit/secret-orbit-node-key.txt`. The lab VM's `hardware_serial` shows the cloud-init seed URL (lab artifact). |
| D-7, D-12 | Not run; need the scheduled sync (launchd) and Duo Desktop. D-11 needs Windows hosts. |

New guide findings from these tests: (1) Linux needs x86-64 for Duo Desktop; (2) a single remaining host that fails a critical policy is never removed from Duo's cache because the sync script refuses an empty list; (3) a failed report fetch leaves `windows.csv` empty; (4) the sync script's `--dry_run` is a safe first step.

## Host A: this Mac (macOS 15.7.7, arm64), 2026-10-07

Fleet host 10 `MPC-Adam`, UUID `EBC70BCE-29B7-5389-8356-2AC6A7D8C240`, fleet Ping Duo Lab. Adam's own Mac, used as host A.

**Enrollment steps and findings**
- The Mac still had an MDM profile for `fleet.mpc.ad`, but Fleet had no host with that UUID or serial (404). Profiles can't reach an orphaned enrollment. Adam removed it by hand.
- An older fleetd install in `/opt/orbit` (also pointed at `fleet.mpc.ad`) made `installer -pkg` fail with "error moving files to final destination" (`shove: Error relinking ... Fleet Desktop.app/Contents/CodeResources: Operation not permitted`). Moved it aside to `/opt/orbit.old-20261007` (delete at teardown); reinstall worked and the host appeared in about a minute. Not a guide issue.
- The `fleetctl package` pkg is unsigned (`installer.log`: "not signed"); fine for `installer`, would be blocked if opened by double-click without a right-click open.
- MDM: Adam turned it on from Fleet Desktop > My device ("On (manual)", User Approved).

| ID | Result | Evidence |
| --- | --- | --- |
| P-1 | **PASS** | Profile `Fleet.LabCA.Scep` installed. Login keychain holds identity `EBC70BCE-...` (CN = host UUID, OU = renewal ID, issuer Fleet Lab CA Intermediate CA, RSA, EKU clientAuth only, KU digitalSignature + keyEncipherment, valid 90 days to 2027-01-05). The step-ca root is in the System keychain; `curl https://ping.lab:9031` gives no TLS error. Fleet showed profile status "verifying" for a while after install. |
| P-14 Safari (baseline) | picker shown | Safari shows "The website ping.lab requires a client certificate" with one identity. macOS always asks; there is no auto-select for Safari. Waiting for Continue. |

Notes: `security verify-cert` on the leaf says `CSSMERR_TP_NOT_TRUSTED` (intermediate not in the keychain), yet Safari lists the identity and PingFederate has the intermediate. To check whether this blocks Chrome. `/etc/hosts` got `127.0.0.1 ping.lab` on this Mac (remove at teardown). A Mac-side screenshot captured Adam's Slack; deleted. Don't take full-screen captures on this host.

### P-14 Safari on macOS: keychain key prompt (2026-10-07) **guide finding**
After Continue in Safari's certificate picker, macOS asked for permission to use the private key in the login keychain (Adam confirmed it was a login keychain prompt). Sign-in did not complete until allowed. Cause: the lab SCEP payload (`lab-ca-scep-user.mobileconfig`) has no `AllowAllAppsAccess`.
- Fleet's own examples set `AllowAllAppsAccess` true (and `KeyIsExtractable` false): `articles/connect-end-user-to-wifi-with-certificate.md`, `articles/enable-okta-verify-on-macOS-with-configuration-profile.md`, `docs/solutions/macos/configuration-profiles/okta-device-access-scep-*.mobileconfig`.
- `articles/pingfederate-conditional-access-integration.md` Step 3 (macOS) says only "Set `PayloadScope` to `User`". **Proposed edit:** also set `AllowAllAppsAccess` to `true` (otherwise the first browser use prompts for the login password) and `KeyIsExtractable` to `false`; point to the Wi-Fi guide's SCEP example.
- Lab fix (pending): add both keys to `lib/macos/configuration-profiles/lab-ca-scep-user.mobileconfig` in the GitOps repo, push, then confirm the profile re-issues the cert and Safari/Chrome sign in with no prompt. **Blocked:** the push was refused by the permission check; waiting on Adam.

### P-1 / P-14 Safari rerun with AllowAllAppsAccess (2026-10-07)
GitOps `f50cb51` added `AllowAllAppsAccess` true and `KeyIsExtractable` false to the lab macOS SCEP profile; apply run 37602394487 succeeded.
- **Finding (Fleet behaviour):** after the edit, Fleet did not re-send the profile to host 10 (status stayed "verifying"/"verified", cert serial unchanged after ~5 min). `POST /hosts/10/configuration_profiles/resend/<profile uuid>` made the Mac re-run SCEP and issue a second cert (new serial); the old cert stayed in the keychain until deleted by hand. For the guide: after changing a SCEP profile, hosts that already have a certificate keep the old key and ACL until the profile is resent or the cert is renewed.
- Old identity deleted (`security delete-identity -Z <sha1>`), one identity left. Safari picker -> Continue: **no keychain prompt, sign-in completed** (Adam confirmed). **P-14 Safari: PASS** (picker still shown every time; Safari has no auto-select).

### P-14 Chrome on macOS (2026-10-07)
- Baseline (no policy): picker, then a keychain prompt, then callback `code=` (Adam). Keychain prompt text not recorded (my own `dump-keychain -d` dialogs were mixed in the same window; Adam asked me to stop spamming). Treat the prompt as unconfirmed.
- With Fleet profile `Fleet.LabCA.ChromeAutoSelect` (payload type `com.google.Chrome`, `AutoSelectCertificateForUrls` = `{"pattern":"https://ping.lab:9032","filter":{"ISSUER":{"CN":"Fleet Lab CA Intermediate CA"}}}`, GitOps `c092846`): **PASS**. Opening the sign-in URL went straight to the callback, no picker, no keychain prompt, no Chrome restart (Adam confirmed). Fleet wrote the preference to both `/Library/Managed Preferences/com.google.Chrome.plist` and `/Library/Managed Preferences/adam/com.google.Chrome.plist`.
- Guide edit: Step 4/5 browser notes should show the macOS profile (preference domain `com.google.Chrome`, same JSON as Windows/Linux, pattern uses the cert-request port).

### macOS sign-in tests on host A (Chrome with the auto-select profile), 2026-10-07
| ID | Result | Evidence |
| --- | --- | --- |
| P-9 | **PASS** | `/tmp/fleet-ca-test` created, Refetch: `failing_critical_policies_count` 1 after about 70 s. Sign-in denied: `error=access_denied`, "Host is not in Fleet or is failing a critical policy". |
| P-10 | **PASS** | File removed, Refetch: count back to 0 after about 55 s; next sign-in returned `code=`. Matches Linux (35 s, range 4 to 148 s) and the guide's "about a minute". Note: `/tmp` is not cleared on macOS reboot the way the Linux VM's is, but macOS cleans it periodically; use a persistent path for long tests. |

### Duo on host A (2026-10-07)
- D-1: Duo Desktop 7.22.0.0 already installed and running on this Mac (policy "Duo Desktop installed (macOS)" passes). Fleet's maintained app is 7.21.0.0, so I can't tell whether Fleet installed it or it auto-updated; the Fleet-driven install is **not proven** here (install on a clean Mac is still to do).
- L-1 (macOS): Duo Desktop logs do not show the device ID. `macos.csv` from the export contains `EBC70BCE-29B7-5389-8356-2AC6A7D8C240`, the Mac's hardware UUID = Fleet host UUID. Whether Duo matches it is decided by D-5.
- D-3/D-4 macOS: export gives 1 row; `device_cache_sync.py` (macOS integration, still disabled): "1 devices uploaded", cache `DCG153...` activated. **PASS**.

### Duo macOS integration activated (2026-10-07)
Signed-in Chrome (Adam logged in). Trusted Endpoints > "Generic with Duo Desktop" (macOS, `DMNV4VV4M97ZYGNW9Z7X`): status toggled to active, **Test with a group = fleet-lab only**, saved (page kept the setting after save). Duo's list showed Last Sync success. Windows and Linux integrations still disabled.
Bypass code for `lab-test` **not created**: the permission check blocked it (creating a bypass is a security-weakening action). Adam creates it himself (Users > lab-test > Add Bypass Code).

### Duo end to end on host A (2026-10-07)
Demo app run locally (`flask` on 127.0.0.1:8443 with the ping.lab cert, redirect `https://ping.lab:8443/duo-callback`); user `lab-test` enrolled Touch ID (Duo requires an enrolled device; a bypass code alone didn't skip enrollment).
| ID | Result | Evidence |
| --- | --- | --- |
| L-1 (macOS) | **PASS** | Duo Desktop's device ID matches the hardware UUID in `macos.csv` (= Fleet host UUID `EBC70BCE-...`). |
| D-5 (allowed) | **PASS** | Auth response: `trusted_endpoint_status: "trusted"`, `device_info_source: "duo_desktop"`, `auth_result: allow`, factor Platform authenticator, group fleet-lab, app Web SDK, Chrome 154 on macOS 15.7.7. |
Guide notes: (1) on macOS 15 with current Chrome, Duo shows "Duo Desktop needs permission to access your local network"; the user must allow the browser's local-network prompt (don't "Skip for now": skipping means no device check). (2) A demo app that asks for a password refuses an empty one; unrelated to the guide. (3) The user needs a Duo enrolled device first; a bypass code alone did not skip enrollment in this setup.

| D-8 (Duo side, macOS) | **PASS** | List replaced by a placeholder ID (this Mac removed, list non-empty): Duo showed "Device not allowed. Your organization requires you to use a trusted device to log in." (Event ID AXHJ5FAVLC5PYVPQTHBO). Original list restored afterwards (cache re-synced with the Mac's UUID). |
| D-8 (Fleet side, critical policy -> export -> Duo) | **Partly proven** | With one macOS host, `REQUIRE_PASSING_CRITICAL_POLICIES=true` would give a header-only CSV, which Duo's script refuses, so the failing host stays trusted (same gap as on Linux). To prove the full chain a second healthy macOS host is needed, or the placeholder trick used here. |

## Phase 8 (2026-10-07), local branch `adam/ping-duo-fixes` off `pr-54346` in `fleet/` (not pushed)
1. `197b11bcd1` export script: temp files + move on success; refuse a list that shrinks by more than 50% unless `FORCE=true`. `tests/test_export_script.sh` extended (26 checks + shellcheck, all pass; the 6 new checks fail on the original script) and given a `timeout` fallback for macOS.
2. import script: search `~/.config/mozilla/firefox/*/` and create the snap Chromium store. Verified on host C: the original script leaves deb Firefox with 0 certificates and no snap Chromium store; the patched one imports into deb Firefox, snap Chromium, Chrome and snap Firefox, and a rerun leaves 1 cert per store.
Note: the test harness lives in the lab folder (`tests/`), not in the PR, which only has the 5 guide/script files.
3. `d818df2503` Ping guide, tested on real hosts: macOS `AllowAllAppsAccess`/`KeyIsExtractable`, EKU comes from the CA, Okta Windows SubjectName, Linux reruns, browser auto-select (port, macOS profile, Firefox), CA trust prerequisite, resend note.
4. `06fefa1d39` Ping guide Steps 4-6 (adapter Client Auth fields, Test Connection URL, `${ad.}`/`${ds.}` names, map `fleetHostID`, single criterion). **Found through the Admin API; hold until VALIDATION.md V-1 to V-6 pass in the UI.**
5. Duo guide: skip empty lists, export safeguards, macOS local network prompt, Linux x86-64, `bash` invocation.
Full diff: `fleet-54654-fixes.diff`. Nothing pushed. Deferred until tested: workflow secrets for Duo scripts (D-6), `report_cap` (D-11), report interval/keep data (D-2), UI-user (cron) path, Windows profile details (P-2).

### PingFederate UI checks (2026-10-07)
See VALIDATION.md "UI check results". Summary: V-1, V-2, V-4, V-5, V-6 confirmed (port required, hostname optional); V-3 partly. Adapter was cleared and restored through the Admin API for V-6; sign-in works after restore. Extra commit on the lab branch: "PingFederate guide: Client Auth Port is required".

### macOS: keychain prompt returns in a second Chrome instance (2026-10-07, after the AllowAllAppsAccess fix)
`open -na "Google Chrome" --args --new-window <url>` (a second Chrome instance) showed "Google Chrome wants to access key 'MDM Allow All' in your keychain" (login keychain password). The key was created by the lab SCEP profile with `AllowAllAppsAccess` true. The normal Chrome instance had gone straight to the callback earlier (state=macchrome2). Possible cause: a separate Chrome instance or a different launch method is treated as a new client. Not yet confirmed; to retest after the reset (fresh key, normal Chrome only, check Always Allow behaviour).

### P-12 and P-13 on macOS (2026-10-07)
- P-13 (macOS): deleting host 10 made fleetd re-enroll the same UUID as host 11 within seconds; a sign-in right then succeeded (new host, policies not yet reporting). Matches Linux.
- P-12 (macOS): with fleetd stopped (`launchctl bootout system/com.fleetdm.orbit`) and host 11 deleted, a Chrome sign-in with the host's certificate returned `error=access_denied`, "Host is not in Fleet or is failing a critical policy". **PASS**. Guide note: deleting a host doesn't revoke its certificate; fleetd re-enrolls it unless it's uninstalled.

### Duo Desktop removed from host A (2026-10-07)
Duo Desktop 7.22.0.0 was **not** installed by the lab: its logs date from 2026-05-13, before the lab started (Oct 6), and Fleet's maintained app is 7.21. So D-1 on macOS was never actually proven. Removed it with Fleet's own uninstall script (`ee/maintained-apps/outputs/duo-desktop/darwin.json`, ref 7d07a79c) so Fleet can install it fresh after re-enrollment. Two background processes (DuoDesktopService, TrustedPeerMessageBroker) kept running from the deleted app until killed. The script's last `trash /Library/Logs/Duo` step needs root; moved by hand.

### macOS reset (2026-10-07)
Host 11 deleted in Fleet; fleetd stopped and uninstalled (`launchctl bootout`, removed `/Library/LaunchDaemons/com.fleetdm.orbit.plist`, `/opt/orbit`, `/opt/orbit.old-20261007`, `/var/log/orbit`, forgot `com.fleetdm.orbit.base.pkg`). Duo Desktop removed. Duo macOS list reset to a placeholder ID so this Mac starts untrusted (for D-7). Still on the Mac: the stale MDM profile (Adam removes it), the lab identity in the login keychain (goes with the profile), `127.0.0.1 ping.lab` in `/etc/hosts`, the Flask demo and callback listener. Firefox install failed (brew hangs at `diskutil eject`); P-16 pending, Adam installs from mozilla.org.

### Restart on host A, round 2 (2026-10-07 evening)
Same Mac, MDM profile NOT removed (Adam: "delete record, let it re-enroll"). Fleet record (host 11) deleted; fleetd reinstalled from `secrets/packages/fleet-osquery.pkg`.
- **MDM re-link:** the new host (12) showed MDM "On (manual)" about 40 s after fleetd enrolled, with no manual MDM step; profiles were delivered. Deleting a host in Fleet doesn't end its MDM enrollment, and re-enrolling fleetd re-attaches it.
- **D-1 macOS PASS:** after removing Duo Desktop, Fleet installed it again (7.22.0.0) through the policy automation within about 2 minutes of fleetd enrolling.
- **P-16 prerequisite:** Fleet installed Firefox (157.0.1, Mozilla team ID 43AQ936H96) through a new policy + `firefox/darwin` maintained app (GitOps `55ff1fa`) about 5 minutes after enrollment.
- **Guide-relevant:** the old lab identity stayed in the login keychain after the host record was deleted and Fleet issued a **second** identity with the same CN; the browser could offer either. Deleted the old one by hand (`security delete-identity -Z`). Fleet doesn't clean up superseded certificates on the host.
- **PingFederate sign-in, normal Chrome, fresh key (round 2):** auto-select worked, callback `code=` (state macr2chrome). Keychain prompt: awaiting Adam's answer.
- **D-7 macOS:** host enrolled ~14:38; first export + sync at 14:42:49 listed the Mac in `macos.csv` (1 row) and Duo reported "1 devices uploaded / Activated". Patched export script run against the live Fleet: output identical to the lab copy's `macos.csv`, no `.duo-export.*` left behind, rerun exit 0 (D-3 with the Phase 8 script).
- **D-7 macOS PASS (auth response):** after the first sync, `trusted_endpoint_status: "trusted"`, `device_info_source: "duo_desktop"`, `epkey` present, `auth_result: allow`, factor `remembered_device` (Duo skipped Touch ID; the endpoint check still ran). Duo Desktop here is the copy Fleet reinstalled. Time from fleetd enrollment (~14:38) to trusted after sync (14:42): one sync cycle.
- **P-16 (macOS) in progress:** Firefox 157.0.1 shows the picker "ping.lab has requested that you identify yourself with a certificate", listing the Fleet identity with "Stored on: OS Client Cert Token", serial 00:BF:73:..., issuer Fleet Lab CA Intermediate CA. So Firefox on macOS uses the OS keychain certificate without extra settings. Outcome of clicking OK pending.
- **P-16 / keychain prompt (macOS):** after OK in Firefox's certificate picker, macOS asked "Firefox wants to access key 'MDM Allow All' in your keychain" (login password). Same dialog for Chrome earlier (second instance) and, on the first key, Chrome after the picker. Safari never prompted. The key carries the "MDM Allow All" label, so the profile's `AllowAllAppsAccess` was applied, yet third-party browsers still ask once. Hypothesis: the key's partition list trusts Apple-signed apps; "Always Allow" remembers the browser. **The guide's claim that `AllowAllAppsAccess` prevents the prompt is too strong: reword to "reduces" / "expect one prompt per browser" until confirmed.** Needs: does the prompt return after "Always Allow"? Does Chrome prompt on a fresh key?
- **P-16 macOS PASS:** Firefox 157.0.1 (installed by Fleet) listed the Fleet identity ("Stored on: OS Client Cert Token"), and after the keychain prompt (Always Allow) PingFederate returned `code=` (state macff). Firefox needs no Firefox-specific setting on macOS to use the OS certificate. It shows its picker every time unless `security.default_personal_cert` is set (not tested on macOS).
- Guide commit: Chrome and Firefox prompt once for the macOS key; wording changed from "prevents" to "expect one Always Allow prompt per browser". Diff regenerated: `fleet-54654-fixes.diff`.
- **P-16 macOS PASS (screenshot confirmed):** Firefox ended on `http://localhost:8765/callback?code=...&state=macff` ("callback ok").
- **P-11:** no client certificate: see line below.
P-11 access_denied count: 1

### D-12 started (2026-10-07 ~15:00 local)
A launchd agent can't run `duo/sync.sh` from `~/Downloads`: "Operation not permitted" (exit 126), macOS privacy protection (TCC) for scripts under Downloads. Removed the agent rather than grant bash Full Disk Access. Instead `duo/sync-loop.sh` runs `duo/sync.sh` every 5 minutes (started with `caffeinate -i` so the Mac doesn't idle-sleep), log in `duo/sync.log`; stop it by deleting `duo/sync.run`. It uses the guide's export script (patched, from the PR branch) in `duo/run`, so the shrink guard works across runs. Guide note for the UI-user (cron/launchd) path: don't keep the script in a folder macOS protects (Downloads, Documents, Desktop) when scheduling it.

### P-15 macOS started (2026-10-07)
step-ca `fleet-scep` default lifetime lowered 2160h -> 48h (`stepca/data/config/ca.json`, backup in the scratchpad `ca.json.bak`; **restore to 2160h at teardown**). Resent "Lab CA client certificate" to host 12: new cert serial `881C08571F93A7359DC5DAD388A4FB1D`, notBefore 2026-10-07 12:48:40 GMT, notAfter 2026-10-09 12:49:40 GMT. Only one identity is in the keychain afterwards (the resend replaced the previous one this time; the earlier resend on 2026-10-07 left two, so superseding behaviour is inconsistent; recheck after renewal).
Fleet's rule (guide, Renewal): validity of 30 days or less renews at half the validity, so the expected renewal is about 2026-10-08 12:49 GMT (14:49 local). Check then: new serial, `notBefore` near that time, number of identities, and that sign-in still works. D-12 runs in parallel; check `duo/sync.log` for FAILED lines.

### Late 2026-10-07: review fixes, D-6 prepared, Windows ARM VM
- Guide commit `d4d8214fab` (local branch): dropped the untested Windows/Linux auto-select pointer, named the resend options (Host details, My device, API), said what the adapter's CN attribute returns. `fleet-54654-fixes.diff` regenerated (8 commits).
- **D-6 prepared, not run:** `.github/workflows/duo-sync.yml` in the GitOps repo (`62576ec`), manual trigger only, restores the three Duo scripts from base64 secrets (`DUO_MACOS_SCRIPT`, `DUO_WINDOWS_SCRIPT`, `DUO_LINUX_SCRIPT`), uses `FLEET_API_TOKEN`, skips an OS with no script or no hosts. Waiting for Adam to set the secrets and run it; then add the 5-minute schedule. It works from any repo, not only a GitOps repo. The export script's shrink guard has nothing to compare against on a fresh Actions checkout.
- **Windows ARM VM (UTM):** Windows 11 26300 installed by an unattended `Autounattend.xml` + answer ISO (UTM's sandbox blocks ISO paths in QEMU arguments; ISOs have to be attached through the UTM UI). A forced stop during setup and a NIC change (e1000e -> virtio) left it in Automatic Repair/recovery; the e1000e card has no inbox driver on this build and the guest agent was never installed, so the VM is unreachable from the Mac. Parked. Windows x64 hardware requested; Duo Desktop for Windows supports Intel only.
- D-12 (`duo/sync-loop.sh`) and P-15 (48 h certificate) still running; check 2026-10-08 afternoon.
- Edge on macOS: dropped (Chrome behaves the same).

### D-6 macOS/Linux PASS (2026-10-07 ~16:40 local)
`duo-sync.yml` (manual run 37645797446 in `AdamBaali/fleet.mpc.ad-gitops`): secrets `FLEET_API_TOKEN` and `DUO_MACOS_SCRIPT`, `DUO_WINDOWS_SCRIPT`, `DUO_LINUX_SCRIPT` (base64) set by Adam; the job restored the scripts, exported the hosts and synced macOS (1 device) and Linux (1 device); Windows skipped (no hosts). Conclusion: success. The guide's "no way to supply the Duo scripts" gap is fixed by base64 repo secrets decoded at run time. The 5-minute `schedule:` is not enabled: the local D-12 loop also uploads to the same integrations, and two uploaders can collide ("a new cache can't be created because one already exists"). Enable the schedule after D-12 ends. Logs on a public repo show only counts and Duo cache keys.

### D-6 redone with keyless script (2026-10-07 ~16:45 local)
Run 37646267078 (`95a077f`): `duo/device_cache_sync.py` in the GitOps repo is Duo's script with the `MKEY_CREDENTIALS` block replaced by environment variables (`DUO_MKEY`, `DUO_IKEY`, `DUO_SKEY`, `DUO_API_HOST`), so the file holds no secrets. Secrets: `FLEET_API_TOKEN`, `DUO_API_HOST`, and per OS `DUO_<OS>_MKEY`, `_IKEY`, `_SKEY` (set by Adam from the downloaded scripts; the three `DUO_*_SCRIPT` base64 secrets deleted). Result: success; macOS 1 device synced and activated, Windows skipped (no hosts), Linux 1 device synced and activated. A local `--dry_run` against the real macOS integration with the same variables also passed. **Guide fix to write:** replace "store each script as a secret" with this: edit Duo's script to read its credentials from environment variables and keep only the keys as secrets. GitHub's log viewer showed no output for the sync step; the raw log archive (`gh api .../actions/runs/<id>/logs`) did.
Mistake logged: while masking Duo's script for inspection, the macOS integration's secret key was printed into the session once (my redaction missed it). Adam chose not to rotate.
- Duo guide commit (local branch, 9th): Step 5 now tells the reader to edit Duo's script to read its credentials from environment variables, commit it, and keep only `FLEET_API_TOKEN`, `DUO_API_HOST` and `DUO_<OS>_MKEY/IKEY/SKEY` as secrets; workflow YAML updated; works from any repo; pointer for non-GitHub schedulers (macOS: keep scripts out of Downloads, Documents, Desktop). The guide's exact YAML wasn't run as written (the lab copy is the same logic with `duo/` paths and a skip message). `fleet-54654-fixes.diff` regenerated.


### Correction (2026-10-07 evening): `fleetHostID` does NOT need to be mapped
Earlier finding ("a lookup attribute is only fetched if mapped to a contract attribute") was wrong. Retested on PingFederate 13.1.3: removed `fleetHostID` from the policy contract and from the contract fulfillment (mapping keys were only `hostUUID` and `subject`), kept lookup 2 as `/api/v1/fleet/hosts/${ds.fleetByUuid.fleetHostID}/health`. Sign-in succeeded (`code=`) and the server log had 0 new error lines. The rejection seen earlier (HTTP 422, "attribute 'fleetHostID' is missing from the attribute contract fulfillment") only applies when the contract itself declares `fleetHostID`. Guide step "map fleetHostID" removed (commit `a7ebfa430d` on the local branch).
Re-proved in the same session, with full log text: (A) `${hostUUID}` in lookup 1 -> `Unknown Key (hostUUID)` and the valid keys are all `ad.x509lab.*`; (D) `${fleetHostID}` in lookup 2 -> `Unknown Key (fleetHostID)`; (C) criterion `fleetHostUUID equals ${hostUUID}` -> log `Comparison Value: ${hostUUID}` vs the real UUID, so the value is literal text (expression-based criteria were not tried). Names depend on the adapter instance ID (`x509lab` here); only one configuration was built.

### Linux Duo Desktop under emulation (2026-10-07 evening)
Duo's Linux install steps (Duo docs): Ubuntu 24.04 supported, ARM not supported, `.deb` from `https://desktop.pkg.duosecurity.com/duo-desktop-latest.amd64.deb`, `dpkg -i`, systemd service `duo-desktop`, no desktop environment or browser extension needed.
Tried on the ARM Ubuntu VM (`lab-linux`) with user-mode emulation:
1. `dpkg --add-architecture amd64`, apt sources for amd64 (archive.ubuntu.com / security.ubuntu.com, existing sources pinned to arm64), `qemu-user-static`, `libc6:amd64` and x86 libs (zlib1g, libstdc++6, libgcc-s1, libssl3t64, libicu74, libkrb5-3).
2. `dpkg -i duo-desktop-latest.amd64.deb` worked on ARM once the amd64 architecture was added (Duo Desktop 4.7.0). The service failed (127) until the x86 libraries were installed.
3. Ubuntu's `qemu-user-static` 8.2.2 crashes the app at start (`QEMU internal SIGSEGV`, MAPERR, right after `openat("/proc/self/maps")`; .NET reads that file). .NET switches (W^X, tiered compilation) did not help.
4. QEMU 10.0.13 static `qemu-x86_64` from Debian's official `qemu-user` package (unpacked, not installed), plus `/lib64/ld-linux-x86-64.so.2` symlink: the app runs. A systemd drop-in (`/etc/systemd/system/duo-desktop.service.d/emulation.conf`) runs the package's binary through it. Result: `duo-desktop` active, listening on 127.0.0.1 and ::1 ports 53100 and 53106 (the local ports Duo uses with the browser), log in `/var/log/duo-desktop/duo-desktop.log`.
Guide note: Duo's own docs say ARM Linux is unsupported; this works only as a lab workaround (emulation, an extra loader link, a newer QEMU). Not for customers.
Pending: Linux integration activated for `fleet-lab` in Duo, then a sign-in from a browser on this VM to confirm the device ID Duo Desktop reports equals `product_uuid` (D-5, L-1 on Linux). Fleet-driven install of the custom package was not tested (installed by hand with dpkg).

### Linux Duo end to end under emulation (2026-10-07 ~17:30 to 18:00 UTC)
- Linux integration ("Generic with Duo Desktop 2") activated for group `fleet-lab` (test group only), done in Adam's signed-in Chrome.
- Browser flow in the VM (Firefox 157 snap, lab-linux, product_uuid `86d7dc8e-...`): Firefox shows "wants to access other apps and services on this device" for `api-...duosecurity.com` (the same local-network permission as on macOS); Allow was needed.
- **Fix for the crash on the first HTTPS request:** `DOTNET_EnableWriteXorExecute=0` for Duo Desktop under QEMU 10 user-mode emulation. The crash was `System.AccessViolationException` in .NET's EventSource startup, not in crypto; CPU-feature switches did not help; JIT-only and tiered-off did not help alone; W^X off did. HTTP port 53106 worked without it, HTTPS port 53100 crashed.
- Attempts: 17:38 Duo page "Install Duo Desktop" (service was crash-looping); 17:46 denied "Endpoint is not trusted" (endpoint page: Trusted Endpoint "Unknown", "Unable to communicate with device health app"; Duo Desktop log: `Error loading computer key` -> `Failed to sign health payload` -> `sending unsigned health payload`, preceded by `Unable to load shared library 'libtss2-tcti-tabrmd.so'`; the VM had no TPM); then enabled UTM's virtual TPM 2.0 (`QEMU.TPMDevice = true` in the VM's `config.plist`, UTM quit first), installed `tpm2-abrmd`, `libtss2-tcti-tabrmd0:amd64` and the unversioned `.so` link, restarted Duo Desktop; 17:56 **granted** with a bypass code (`Valid passcode`), device "Ubuntu 24.04 as reported by Duo Desktop"; endpoint page: **Trusted Endpoint: Yes ("Trusted endpoint enrolled in your management system, via device health")**, Duo Desktop 4.7.0.
- **D-5 Linux PASS, L-1 Linux PASS** (ID Duo matched = `product_uuid` = Fleet host UUID = CSV row). The `Error loading computer key` message still appeared after the TPM was added, so the health payload stayed unsigned; whether the TPM or Duo's processing delay after activating the integration made the difference is **not established**. Do not claim a TPM requirement in the guide without a controlled test (disable the TPM, restart, retry).
- The Duo docs page for the generic Linux integration lists no TPM requirement and says Duo Desktop 4.7.0+ falls back to `/etc/machine-id` (as a UUID with dashes) when the product UUID isn't available; the general Duo Desktop docs say Linux/Windows devices "should support TPM 2.0" if you require device registration.
- Not done: D-8 sign-in block on Linux (the 5-minute sync loop would overwrite a temporary list; the sync-level behaviour was shown earlier), a Fleet-driven install of the custom package (Duo Desktop was installed with `dpkg -i` as in Duo's docs), L-2.
- Lab-only: user-mode emulation, QEMU 10 from Debian, W^X off, TPM. Duo documents ARM Linux as unsupported.

### Linux A-to-Z with evidence (2026-10-07 evening)
Full Linux run with per-test evidence (raw output, VM screenshots, sanitized config): `testing/conditional-access-54654/test-evidence/linux/REPORT.md` in the public lab repo (commit `31e3156`). 22 PASS, 2 PARTIAL (D-1: Duo Desktop only runs on the ARM VM through emulation; D-12: day-long result pending), 0 FAIL. Highlights: P-6b retracted the "map fleetHostID" claim; P-9/P-10 timing was 146 to 160 s this run; P-14 shows the Chromium and Firefox pickers and the port finding; D-5/L-1/D-8 show Duo allowing, blocking and re-allowing the Linux VM with Duo's own log and endpoint records. macOS renewal watcher: `evidence/renewal/watch.log` (7-hour certificate that crosses midnight UTC).
Harness notes: the public repo's `.gitignore` has `evidence/` (Adam's May rule), so the folder is published as `test-evidence/`; bypass code and public IP live in `.env` (`DUO_BYPASS_SECRET`, `LAB_PUBLIC_IP`) and are redacted.

### Incident: GitOps applies failed from 15:42 to 19:03 UTC on 2026-10-07 (my mistake)
The command I gave Adam to set the Duo workflow secrets saved the read-only `duo-observer` token as the repo secret `FLEET_API_TOKEN` at 15:40 UTC. The GitOps workflow (`workflow.yml`) reads the same secret name, so every apply after that failed with `error deleting EULA: getting eula metadata: forbidden` (runs for `95a077f` to `31e3156`, plus the nightly). The lab Fleet kept its last good configuration; nothing was changed or lost.
Fix (19:03 UTC): Fleet can't re-issue an API token, so I created a new API-only user `gitops-lab` (global role `gitops`) and saved its token as `FLEET_API_TOKEN`; the Duo token now lives in `DUO_FLEET_API_TOKEN` and `duo-sync.yml` reads that. GitOps apply green again (`1238411`), Duo sync run `37671183679` green. The previous GitOps user's token (the `Claude` admin API user) is no longer used by the workflow; consider deleting that user. The Duo guide now uses `DUO_FLEET_API_TOKEN` and warns about the collision (commit on the lab branch).

### P-15 macOS: plan changed (2026-10-07 19:40 UTC)
The 6h57m certificate (issued 18:03:49, expiring 01:00:49 UTC Oct 8, `DATEDIFF`=1) was not renewed by 19:37 UTC although it was eligible under a half-day reading and Fleet's hourly job should have run at least once. Fleet computes validity with `DATEDIFF` (whole calendar days) and renews when `not_valid_after < NOW + validity_period/2 DAY`; for `DATEDIFF`=1 the half is 0.5 day, which MySQL does not apply as half a day, and Fleet's docs only support renewal for validity of 2 days or more. So that certificate would probably renew only after it expires. Other checks at 19:37: Fleet error store empty (`fleetctl debug errors`), no new InstallProfile command for the host since 12:40Z (user-channel resends don't appear in `fleetctl get mdm-commands --host`), activity log shows only GitOps applies and my two resends, profile status verified. Server logs (the "Renewing MDM managed certificates" line) are on Render and not readable through `fleetctl`.
New test: step-ca `fleet-scep` lifetime 1710 min; certificate serial `A8EAEE3123AB6DC21B5F51A9AC816738` issued 2026-10-07 19:38:51 GMT, expires 2026-10-09 00:09:51 GMT (28h31m, `DATEDIFF`=2). By Fleet's rule the renewal window opens 2026-10-08 00:09 UTC; expect a new serial after the next hourly job (by about 01:10 UTC). The watcher `evidence/renewal/watch.sh` keeps logging every 5 minutes. If it renews, record: new serial, notBefore, number of identities, and a sign-in.

## P-15 macOS certificate renewal (2026-10-08): PASS (renewed twice, unattended)
**Setup:** step-ca `fleet-scep` lifetime 1710 min (28.5 h) so renewal happens within a day. The first certificate (7 h, `DATEDIFF`=1 day) never renewed: Fleet counts whole days (see 2026-10-07 notes).
**Observed (watch log `evidence/renewal/watch.log`, `overnight.log`):**
| Certificate | Issued (UTC) | Expires (UTC) | Fleet renewal window opens | Renewed at |
| --- | --- | --- | --- | --- |
| `A8EAEE31...` | 2026-10-07 19:38:51 | 2026-10-09 00:09:51 | 2026-10-08 00:09:51 | `F0F14345...` issued 00:39:01 (29 min later) |
| `F0F14345...` | 2026-10-08 00:39:01 | 2026-10-09 05:10:01 | 2026-10-08 05:10:01 | `F7313E7E...` issued 05:38:40 (29 min later) |
| `F7313E7E...` | 2026-10-08 05:38:40 | 2026-10-09 10:09:40 | 2026-10-08 10:09:40 | expected about 10:38 |
- The login keychain held exactly 1 identity before and after each renewal (171 watcher samples, none with 2): the old certificate is replaced, not left behind.
- Profile `Lab CA client certificate` shows `verifying` for a few minutes after each renewal, then `verified`. No activity-log entry and no host "upcoming activity" appear for a renewal; the only evidence is the keychain and the profile status.
- The renewal comes about 29 minutes after the window opens, because Fleet's check runs hourly (at about :38 past the hour in this instance).
- With a 28.5 h certificate the rule is `validity = DATEDIFF(notAfter, notBefore)` = 1 or 2 days; a validity of 1 day (28.5 h spanning two dates gives 1) renews when under 1 day is left, so the certificate renews about every 5 hours. This is a lab artefact of the short lifetime, not a guide issue. Production certificates (a year, or 30+ days) renew 30 days out.
- Still to do: confirm a Chrome sign-in works with the renewed certificate (needs a visible Chrome window on the Mac; do when Adam is at the Mac).

## GitHub scheduled Duo sync (2026-10-08): PARTIAL
Cron `2-59/5 * * * *` was on `main` from 2026-10-07 22:12 UTC. First scheduled run came at 02:02 UTC, about 4 hours later, and only 1 scheduled run was seen in the next 6 hours. GitHub does not guarantee schedule timing; new or low-traffic schedules can be delayed or skipped. A 5-minute Actions schedule is therefore not reliable for the 5-minute Duo sync the guide promises. The local loop (`duo/sync-loop.sh`) kept a steady 300 s median gap (235 cycles, 0 failed).
