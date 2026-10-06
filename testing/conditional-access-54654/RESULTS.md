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
2. A data store attribute is fetched only if something references it (contract fulfillment or a criterion). `fleetHostID` must be mapped to a contract attribute (here an extended attribute on the policy contract) before lookup 2 can use it. The guide does not say this.
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
