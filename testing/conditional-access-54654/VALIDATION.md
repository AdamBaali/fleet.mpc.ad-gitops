# Validate before posting: PingFederate findings

Rule: don't post a finding to the issue or send it to Noah until it is marked **Validated** here. Everything in this lab was configured through PingFederate's Admin API and an OAuth test client, not the admin UI the guide describes. These checks confirm the UI behaves the same.

Setup: PingFederate admin UI at https://localhost:9999/pingfederate/app (user `Administrator`, password in `.env` as `PING_ADMIN_PASSWORD`; copy it with `grep ^PING_ADMIN_PASSWORD= .env | cut -d= -f2- | pbcopy`). Needs: `docker ps` shows `pingfederate`, the Linux VM is running (so bridge `192.168.64.1` exists), Fleet host for the VM is online.

Sign in from the Mac with the Linux host's certificate (a valid host UUID must exist in Fleet; the cert in `ping/certs/clients/hostC2.*` has CN = the Linux VM's UUID):
```bash
cd /Users/adam/Downloads/fleet-54654-lab/ping
./signin-test.sh certs/clients/hostC2.crt certs/clients/hostC2.key     # code= means success; error_description= is the denial text
docker exec pingfederate sh -c 'grep -E "Unknown Key|Comparison Value|Actual Value|Authorization failed|Problem with attribute lookup" /opt/out/instance/log/server.log | tail -8' | cut -c1-260
```
If the VM isn't enrolled any more, enroll it first or use the host UUID of whichever host is in Fleet (issue a cert with `step ca certificate` as in `RESULTS.md`).

| ID | Finding to validate | UI steps | Expected (what I saw through the API) | Outcome (fill in) |
| --- | --- | --- | --- | --- |
| V-1 | `${hostUUID}` and `${fleetHostID}` don't resolve in a lookup path | Authentication > Policies > Policies > "Fleet device check" > the Policy Contract node > Contract Mapping > Attribute Sources & User Lookup > the first Fleet source. Look for a variable picker or hint. Change the path to `/api/v1/fleet/hosts/identifier/${hostUUID}?exclude_software=true`, save, run the sign-in. | Denied. Log: `Unknown Key (hostUUID)` and the list of valid keys (`ad.x509lab.CN`, ...). | |
| V-2 | Working names are `${ad.<adapter id>.CN}` and `${ds.<source id>.fleetHostID}` | Put the real names back (`${ad.x509lab.CN}`, `${ds.fleetByUuid.fleetHostID}`), sign in. Note whether the UI suggests or auto-completes them. | Success (`code=`). Write down what the UI shows for variable names. | |
| V-3 | `fleetHostID` must be mapped to something, or it is never fetched | Open the second lookup's path (`/api/v1/fleet/hosts/${ds.fleetByUuid.fleetHostID}/health`). In the Contract Fulfillment step, remove the mapping of `fleetHostID` from the first source (leave only `hostUUID` and `subject`). Sign in. | Lookup 2 fails with `Unknown Key`. If the UI fetches all attributes automatically, this finding is wrong. | |
| V-4 | The criterion "`fleetHostUUID` equals `${hostUUID}`" can never pass | Issuance Criteria tab: add Source = the first Fleet source, Attribute = `fleetHostUUID`, Condition = equal to, Value = `${hostUUID}`. Sign in. Note any hint in the Value field. | Denied; log shows `Comparison Value: ${hostUUID}` and `Actual Value(s): <the UUID>`. Also try Value = `${ad.x509lab.CN}`: if that passes, the guide's idea works with the right name. | |
| V-5 | The single criterion `failingCriticalPolicies equals 0` blocks unknown hosts | Remove the V-4 criterion; keep only `failingCriticalPolicies = 0`. Sign in with a cert for a UUID that is not in Fleet (issue one with `step ca certificate <new uuid>`). | Denied, not a server error. | |
| V-6 | The X.509 adapter needs Client Auth Port and Hostname | Authentication > Integration > IdP Adapters > the X.509 adapter: clear Client Auth Port and Client Auth Hostname, save, sign in. Then restore 9032 and ping.lab. | **Unknown.** Record exactly what happens. If sign-in still works, change the guide wording from "needs" to "set". | |
| V-7 | Guide's OAuth-only notes: IdP Authentication Policies must be on, and Access Token Mappings must exist | Authentication > Policies: untick "IdP Authentication Policies", sign in; re-tick. Applications > OAuth > Access Token Mappings: note the two entries. | Without the checkbox the policy tree isn't used. Only relevant to OAuth tests, not to the guide. Don't post unless the guide is about OAuth. | |
| V-8 | Behaviour is the same with a SAML or OIDC connection, not only OAuth | Optional: add a simple SAML SP connection using the same policy contract and sign in through it. | Same decisions. | |
| V-9 | PingFederate version differences | Check the version in the UI footer (13.1.3 here). Ask Noah which version the guide was written against. | Findings may differ on other versions. | |

## Findings and their status

| Finding | Status |
| --- | --- |
| Lookup variable names (`ad.`/`ds.`) | Log-confirmed through the API. Validate V-1, V-2. |
| `fleetHostID` must be mapped | Observed. Validate V-3. |
| Criterion with `${hostUUID}` never passes | Log-confirmed. Validate V-4. |
| `failingCriticalPolicies = 0` alone blocks unknown hosts | Tested on a deleted host and an unknown UUID. Validate V-5. |
| Client Auth port and hostname required | **Not tested without them.** Validate V-6. |
| Chrome/Edge auto-select pattern must use the cert-request port | **Validated** (picker returned with the 9031 pattern). |
| Firefox auto-select setting | **Validated.** |
| Linux import script misses the XDG Firefox path; skips snap Chromium store; needs reruns | **Validated.** |
| Windows Okta Verify profile CN is the serial number | Validated by reading the file. The effect on sign-in is not tested (needs a Windows host). |
| Duo: empty list refused so failing host stays trusted; failed report leaves empty CSV | **Validated** on Linux. |
| Duo Desktop for Linux is x86-64 only | From Duo's documentation, not tested here. |
| Recovery about 35 s after Refetch | Measured on Linux; ranged 4 to 148 s. State as a range. |
| macOS and Windows sign-in, Fleet auto-renewal | **Not tested.** |

When a row is validated, change its Outcome here, then update `GUIDE-FINDINGS.md`, then post.
