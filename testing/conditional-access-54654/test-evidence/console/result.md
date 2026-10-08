# Console pages (2026-10-08)
Window-only captures of Adam's browser (Fleet and Duo Admin, lab accounts). The browser profile area, admin name, MAC address, public IP and serial number are masked.

| File | What it shows |
| --- | --- |
| `fleet-mac-host-policies.png` | Mac host (`MPC-Adam`, fleet Ping Duo Lab): critical policy "CA test - flag file absent" passes, "always fails (non-critical)" fails, Duo Desktop and Firefox installed policies pass |
| `fleet-linux-host-policies.png` | Linux host (`lab-linux`): same two CA test policies (critical passes, non-critical fails) |
| `fleet-os-settings-ping-duo-lab.png` | Controls > OS settings for the Ping Duo Lab fleet: Lab CA client certificate, Lab CA root certificate and other profiles; Verified 1 host, Failed 0 |
| `fleet-ca-list.png` | Settings > Integrations > Certificate authorities: `LAB_CA`, Custom SCEP (the entry itself is not opened, so the challenge is not shown) |
| `duo-endpoints-trusted.png` | Duo Endpoints: both lab hosts (Mac OS X with Chrome, Linux with Firefox) are **Trusted Endpoint: Yes**, "Generic with Duo Desktop" |
| `duo-applications-web-sdk.png` | Duo Applications: the Web SDK app with the group policy "Fleet lab - trusted endpoints only" for group `fleet-lab` |

Not captured: the Duo authentication log (the URL tab showed "Not Found") and the PingFederate admin console (the browser pane refuses https://localhost; capture it in your own browser at https://localhost:9999/pingfederate if wanted).

## Added later (2026-10-08)
| File | What it shows |
| --- | --- |
| `fleet-ca-lab-ca-settings.png` | The LAB_CA edit form: name `LAB_CA`, SCEP URL `https://scep.mpc.ad/scep/fleet-scep`; the challenge field is masked by Fleet (dots only) |
| `duo-authentication-log.png` | Duo Authentication Log (zoomed out, last 24 hours, all rows for `lab-test`, Web SDK app). **Mac:** Denied "Endpoint is not trusted" at 9:02:55 UTC (the D-8 block) then Granted at 9:05:43 after the sync restored the Mac, both "as reported by Duo Desktop". Earlier Mac rows: Denied "Endpoint is not trusted" 11:22 on Oct 7 (before the Mac was in the list), Granted 12:43. **Linux (Ubuntu 24.04, Duo Desktop under emulation):** Denied "Duo Desktop was not installed or running" 5:38 PM, Denied "Endpoint is not trusted" 5:46 PM and 6:50 PM (D-8), Granted with a bypass code at 5:56, 6:46 and 6:53 PM. Your admin name and the profile area are masked |

## PingFederate admin console (2026-10-08)
| File | What it shows |
| --- | --- |
| `pingfederate-idp-adapter-x509lab.png` | Summary of the IdP adapter instance "Fleet X.509" (`x509lab`, X.509 Certificate IdP Adapter 1.3.2): **Client Auth Port 9032**, **Client Auth Hostname ping.lab**, parse subject and issuer DNs on, extended contract attributes (ClientCertificateChain, email...) |
| `pingfederate-data-store-fleet.png` | Summary of the REST data store "Fleet": base URL `https://fleet.mpc.ad`, method GET, header `Authorization: Bearer <token masked>`, attributes `fleetHostUUID /host/uuid`, `fleetHostID /host/id`, `failingCriticalPolicies /health/failing_critical_policies_count`, `fleetHostname`, `fleetTeamID`, `fleetHostIDText` |
The token row in the data store summary is a real Fleet API token (the read-only `ping-observer` user). It is masked in the saved picture. Do not capture that row unmasked.
| `pingfederate-oauth-client-labclient.png` | OAuth client "Lab test client" (`labclient`): client authentication type None, redirect URI `http://localhost:8765/callback`; the test client used for the browser sign-ins in P-7 to P-16 |
| `pingfederate-policy-contract-grant-mapping.png` | OAuth > Policy Contract Grant Mapping: the mapping "'Fleet device check' to Persistent Grant Contract" (the policy contract used by the lab is named **Fleet device check**) |
| `pingfederate-policy-contract-mapping-summary.png` | That mapping's summary: USER_KEY and USER_NAME come from `subject` of the authentication policy contract; no data sources, no issuance criteria on this mapping (the Fleet lookups and criteria are in the authentication policy, not here) |
| `pingfederate-authentication-policy.png` | Authentication > Policies list: policy **Fleet device check**, authentication source **Fleet X.509**, policy contract **Fleet device check**, enabled |
| `pingfederate-authentication-policy-tree.png` | The policy's edit page: adapter "Fleet X.509" -> FAIL: Done; SUCCESS: policy contract "Fleet device check" (with its Contract Mapping link). The Fleet lookups and issuance criteria are inside the contract mapping |
Note: PingFederate warns that using its console in several tabs can corrupt its configuration. Capture it from one tab and use Cancel, not Save.
| `pingfederate-contract-mapping-attribute-sources.png` | Authentication policy contract mapping, Attribute Sources & User Lookup: the two lookups **Fleet host by UUID** and **Fleet host health** |
| `pingfederate-contract-mapping-summary.png` | The whole Step 6 configuration on one page. Lookup 1 `fleetByUuid`: resource path `/api/v1/fleet/hosts/identifier/${ad.x509lab.CN}?exclude_software=true`. Lookup 2 `fleetHealth`: `/api/v1/fleet/hosts/${ds.fleetByUuid.fleetHostID}/health`. Contract fulfillment: `fleetHostID` from the data store, `hostUUID` = CN (adapter), `subject` = SubjectDN (adapter). Issuance criterion: `fleetHealth` attribute `failingCriticalPolicies` equal to `0`, error message "Host is not in Fleet or is failing a critical policy". This is also the evidence for P-6: the second lookup uses `${ds.fleetByUuid.fleetHostID}` and the first uses `${ad.x509lab.CN}`, not `${hostUUID}` or `${fleetHostID}` |

## Result: INFO

Reference pictures, not a test.
