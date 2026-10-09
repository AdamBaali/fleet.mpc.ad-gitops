# How the pieces report to each other (Google conditional access for iPhones)
Pattern reused from the #54654 lab (Duo "mark devices as managed" and PingFederate): Fleet stays the source of truth, a small script
copies state to the identity provider, the IdP decides at sign-in. Noah's draft guide follows the same shape (the PR says it "follows the same
structure and wording as the Duo and PingFederate guides").

## Data flow
```
iPhone --MDM--> Fleet (host, end user email, MDM status)
Fleet API --(GET /hosts?device_mapping=true, API-only Observer token)--> sync script
Google (device list, deviceUsers) --(Cloud Identity API, delegated service account)--> sync script
sync script --(PATCH clientStates/<customer-no-C>-fleet: managed, complianceState, customId)--> Google
Google Context-Aware Access --(device.vendors[...].is_managed_device)--> allow or deny sign-in (Drive, Gmail)
```
| From | To | How | How often | Where to see it | Failure looks like |
| --- | --- | --- | --- | --- | --- |
| iPhone | Fleet | MDM enrollment, end user email (IdP or custom mapping) | At enroll, then check-ins | Fleet host details, MDM status, `device_mapping` in the API | No email: host never matches, device stays blocked |
| iPhone | Google | Sign in to a Google app, basic mobile management adds the device | At sign-in | Admin console > Devices > Mobile and endpoints; `devices.list` | No device in Google: nothing to mark |
| Fleet | script | `GET /hosts` (paged, `device_mapping=true`) | Per run | Script output; GitHub Actions log | 401/403: script stops. Empty list: see risk below |
| script | Google | `clientStates.patch` | Per run, only on change | Script output "name (key): none -> MANAGED"; Admin console device page; `clientStates.get` | 403 delegation missing (seen: `unauthorized_client`) |
| Google | iPhone user | Context-Aware Access, Continuous evaluation | At sign-in and during sessions | Admin console > Reporting > Audit and investigation > **Context Aware Access log events** (entries usually appear within an hour); fields: access level applied, satisfied, unsatisfied, actor, application, device ID, device state, decision (Access Evaluated or Access Denied, and "(Monitor mode)" variants) ([Google](https://knowledge.workspace.google.com/admin/reports/context-aware-access-log-events)) | Monitor mode shows would-be denials only |
| GitHub Actions | script | schedule + `workflow_dispatch` | Every 5 min in the guide | Actions run log, secrets masked | Duo lab: GitHub's schedule is best effort (2 runs in 11 hours), free plan has 2,000 minutes a month (about 7 days at 5-minute runs) |

## Reporting to Adam (what we capture per test)
For each test: the `.mov`, window-only PNGs, the **script output**, the **Context Aware Access log event** for the sign-in (screenshot, user email masked),
the Fleet host page (masked), and the GitHub Actions log. One `result.md` per test, built into `EVIDENCE.md` with `_framework/bin/build-evidence-index.py`.

## Lessons from Duo and Ping that apply here (new tests added to TEST_PLAN)
| Duo / Ping finding (#54654) | Google equivalent | Test |
| --- | --- | --- |
| An empty or partial export replaces the whole cache | If Fleet returns 0 hosts (wrong token scope, outage, empty fleet) the script marks every matched Google device UNMANAGED, so everyone is blocked. The guide has no "refuse a big drop" guard | E-13 |
| 5-minute schedule is unreliable and costs minutes | The guide uses the same 5-minute cron and a private repo | G-12 (run it for hours, record runs and misses) |
| Separate secret names from the GitOps workflow (`FLEET_API_TOKEN` belongs to GitOps) | The guide's workflow reuses `FLEET_API_TOKEN` | G-7 |
| Keys in scripts go in repo secrets | The service account JSON goes in `GOOGLE_CREDENTIALS`, token via `google-github-actions/auth` with `access_token_subject` | G-7 |
| Passing critical policies, not just "managed" (Ping `failing_critical_policies_count`, Duo `REQUIRE_PASSING_CRITICAL_POLICIES`) | The script sets complianceState COMPLIANT for any matched host and ignores Fleet policies (policy-based access is out of scope, tracked in fleetdm/fleet#52414) | Note only |
| Platform limits found late (Duo Desktop x86-64 only) | Check iPad vs iPhone matching and one device per user per type | E-4 |

## New finding to verify on the first live device (high priority)
Google's reference for `clientStates` says the resource name's partner segment is `{customer}-suffix` where the customer ID is **your customer ID without the leading "C"**
([docs](https://docs.cloud.google.com/identity/docs/reference/rest/v1/devices.deviceUsers.clientStates), read through a summary, not yet confirmed by a live call).
The guide, the script and the access level condition all use the customer ID WITH the "C" (`<customer-ID>-fleet`). If Google's doc is right the partner ID is wrong, the
patch fails, and the CEL condition never matches. Test: PATCH with both forms on a real device, check which one `device.vendors` resolves. If the "C" form fails, fix the script, the guide and the access level.
