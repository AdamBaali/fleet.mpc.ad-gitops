# Guide findings: PingFederate and Duo (fleetdm/fleet#54654, PR #54346)

What the lab tests showed, grouped by guide. Evidence for each item is in `RESULTS.md`. Test IDs (P-n, D-n, L-n) are from `TEST_PLAN.md`.
**Validation:** items marked in `VALIDATION.md` as not yet validated were found through the PingFederate Admin API and still need a check in the UI. Don't treat them as final.

Status: the design works. The Fleet APIs, the JSON paths and the critical-policy logic are correct. The PingFederate setup steps need the fixes below.

## PingFederate guide

| # | Step | Finding | Proposed edit |
| --- | --- | --- | --- |
| 1 | Prerequisites | PingFederate 13.1.3 already contains the X.509 adapter (1.3.2). No separate kit install. | Say "installed" applies to older versions only, or note the version. |
| 2 | Step 3 (Windows) | The Okta Verify profile it links to sets `SubjectName` to the serial number (`CN=$FLEET_VAR_HOST_HARDWARE_SERIAL managementAttestation`) with no renewal OU. | Tell users to change `SubjectName` to `CN=$FLEET_VAR_HOST_UUID,OU=$FLEET_VAR_CERTIFICATE_RENEWAL_ID`. |
| 3 | Step 3 | The extended key usage comes from the CA's certificate template. The Apple SCEP payload has no EKU key. | Reword: the CA must issue client authentication certificates. |
| 4 | Step 3 | Hosts need the CA root certificate trusted for browsers to accept the PingFederate server certificate chain. Not mentioned. | Add a step to deploy the CA root (macOS root payload, Windows `RootCATrustedCertificates`). |
| 5 | Step 3 (Windows) | Fleet's custom SCEP Windows example uses a 1024-bit key and SHA-1. The lab CA requires 2048 bits. The Okta Verify guide calls `CAThumbprint` "SHA-256" but shows a 40-character value. | Use 2048 and SHA-2. State that `CAThumbprint` is the SHA-1 fingerprint of the root. (Windows not yet verified.) |
| 6 | Step 3 (Linux) | `import-certificate-to-browsers.sh` misses current Firefox profiles in `~/.config/mozilla/firefox`. After the guide's script ran, the deb Firefox store was empty. | Apply `patches/import-certificate-to-browsers-firefox-xdg.patch` (P-3). |
| 7 | Step 3 (Linux) | The script skips browser stores that do not exist yet (new Firefox profiles, snap Chromium `~/snap/chromium/current/.pki/nssdb`) and users created later. | Create the snap Chromium store; state that the script must be rerun (P-4). |
| 8 | Step 4 | The X.509 adapter needs **Client Auth Port** (the secondary HTTPS port, 9032) and **Client Auth Hostname**. | Add both settings. |
| 9 | Step 4 | The server base URL and virtual host name must be the name browsers use, or redirects go to `localhost`. | Add to prerequisites. |
| 10 | Step 5 | The REST data store has a Test Connection URL and a Test Connection action. Passes with `/api/v1/fleet/me` and the Bearer header (P-5). | Add: set Test Connection URL, run Test Connection. |
| 11 | Step 6 | `${hostUUID}` and `${fleetHostID}` do not resolve in a lookup path ("Unknown Key"). Adapter attributes are `${ad.<adapter id>.<attribute>}` (for example `${ad.x509lab.CN}`). An earlier lookup is `${ds.<source id>.<attribute>}` (P-6). | Use the real variable names. |
| 12 | Step 6 | A data store attribute is fetched only if something references it. `fleetHostID` must be mapped to a contract attribute before lookup 2 can use it. | Add the mapping step. |
| 13 | Step 6 | The criterion "`fleetHostUUID` equals `${hostUUID}`" can never pass. A condition value is literal text, and expression criteria are disabled by default. | Remove it. "`failingCriticalPolicies` equals 0" alone denies unknown hosts, because lookup 2 cannot resolve. |
| 14 | Step 6 / OAuth | For a browser OAuth flow: enable **IdP Authentication Policies**, and create Access Token Mappings for the adapter and the policy contract. Without them: "There are no authentication methods available for OAuth". | Add a note for OAuth users. |
| 15 | After Step 6 | A host that has not run its policies yet is allowed (unrun policies are not counted as failing) (P-13). | Keep the note. |
| 16 | After Step 6 | Recovery: after the fix and **Refetch**, Fleet showed the host passing in about 35 seconds (P-10). First flip to failing took 4 to 96 seconds. | Keep "about a minute". |
| 17 | Last paragraph | `AutoSelectCertificateForUrls` for Chrome and Edge needs the host and port that request the certificate (here `https://ping.lab:9032`), not the sign-in URL (P-14). | Say so. |
| 18 | Last paragraph | Firefox always shows a certificate picker. Auto-select: policy `security.default_personal_cert` = "Select Automatically" (P-14). | Add a Firefox line. |
| 19 | Lab only | step-ca limits certificate lifetime to 24 hours by default. | Mention CA lifetimes if the guide discusses them. |

## Duo guide (partly tested)

| # | Finding | Proposed edit |
| --- | --- | --- |
| 1 | The export script runs correctly against a live Fleet (D-3). Three CSVs with a `device_id` header. | None. |
| 2 | The export script writes each CSV straight to its final name. A failed report fetch leaves an empty `windows.csv` (D-9 risk). No check for a list that suddenly shrinks. | Write to temp files, move on success; refuse a drop of more than 50% unless `FORCE=true`. |
| 3 | The workflow cannot get Duo's sync scripts (they contain keys). | Store them as base64 repo secrets and decode at run time. |
| 4 | The workflow suits GitOps users only. | Add a path for UI users (cron or scheduled task). |
| 5 | Duo's integration page recommends daily syncs. The guide says every 5 minutes. | Keep 5 minutes only if D-12 passes. |
| 6 | The sync script has `--dry_run` and `--delete_existing_cache`. | Mention `--dry_run` for the first run. |
| 7 | The integration page shows the API network allow-list empty (open to all networks). | Suggest restricting it. |
| 8 | Duo Desktop for Linux is x86-64 only. ARM is not supported yet (Duo documentation). Could not test Linux L-1, D-5 on an arm64 VM. | Add "x86-64" to the Linux requirements. |
| 9 | If the only host for an OS fails a critical policy (with `REQUIRE_PASSING_CRITICAL_POLICIES=true`), the export is empty and Duo's `device_cache_sync.py` refuses to upload it (exit 1). The old cache stays, so the failing host stays trusted in Duo (D-8). | Document it, or have the workflow handle an empty list on purpose. |
| 10 | A header-only or empty CSV is not a risk: Duo's script deletes the new cache and exits 1 without replacing the active one (D-10). A partial list is the risk. | Keep the "refuse a big drop" guard. |
| 11 | A failed report fetch leaves `windows.csv` empty with no header; an invalid token fails before writing anything (D-9). | Write to temp files, move on success. |
| 12 | Fleet showed policy changes after 134 to 148 seconds on a freshly started VM (4 to 35 seconds on other runs). Plan for up to a few minutes plus the sync interval (D-8). | Say a failing host can stay trusted for a few minutes plus one sync. |

## Secrets in profiles (both guides)
`$FLEET_SECRET_*` variables work in the UI (**Controls > Variables**) and in GitOps (repo secret plus a `FLEET_SECRET_*` line in the workflow `env`). A GitOps dry run does not fully validate profiles with variables. Show both paths where a profile needs a value such as the CA thumbprint.

## Lab notes that are not guide issues
GitOps resets a CA added in the UI, so declare it in `default.yml`. The Duo demo needs an HTTPS redirect URI with a hostname, not an IP. UTM cannot attach removable media by script; the Linux VM is built with cloud-init over HTTP (`linux-vm/`).
