# Mac Evaluation Utility checks as Fleet reports

Apple's Mac Evaluation Utility (MEU) checks whether a Mac and its network are ready for managed deployment.
It runs on one Mac at a time, by hand. These Fleet reports run the same checks on every Mac, every day,
and keep the results in Fleet.

MEU version: 4.8.1 (catalog 040800, April 2026). Status: built and checked without a Mac. Not yet run on a host.


## What's here

| Path | What it is |
| --- | --- |
| `../../lib/macos/reports/mac-evaluation-utility.reports.yml` | The five Fleet reports. Generated. `default.yml` references it, so it runs on every Mac in the lab |
| `COVERAGE.md` | Every MEU test, and the osquery source for it or the reason there is none. Generated |
| `tools/build-meu-reports.py` | Builds both files above from the test catalog inside the MEU app |
| `tools/sqlite-logic-check.py` | Runs every report against a compliant and a non-compliant fixture host in SQLite |
| `TEST_PLAN.md` | What still has to run on a real Mac |
| `HANDOFF.md` | Where the work stands and what to do next |


## The reports

| Report | MEU categories | Rows per host |
| --- | --- | --- |
| MEU - Computer and network information (macOS) | Computer Information, Network Information | 13 |
| MEU - Mac management and identity (macOS) | Mac Management (Apple Intelligence, Management, Security, Managed Software Updates), Identity Management | 62 |
| MEU - Application information (macOS) | Application Information | 7 |
| MEU - Apple network services (macOS) | Apple Network Services, except push notification hosts | 145 |
| MEU - Push notification hosts (macOS) | Push Notifications (ports 443 and 5223), HTTPS interception | 103 |

Every report returns the same five columns:

| Column | Meaning |
| --- | --- |
| `meu_id` | MEU's test ID. It matches the test in an MEU CSV or JSON export |
| `category` | MEU's category or subcategory title |
| `test` | MEU's test title |
| `result` | `PASS`, `WARN`, `FAIL`, or `INFO`, from MEU's own severity for that outcome |
| `value` | What the host returned |

MEU severities map to results this way: Success is `PASS`, Critical and Major are `FAIL`, Minor is `WARN`,
and Informational is `INFO`.


## Coverage

MEU 4.8.1 runs 376 tests. The reports cover 344. The other 32 need data osquery can't read: Bonjour
browsing, UDP and SFTP probes, Touch ID enrollment, bootstrap token and volume ownership status,
extensible SSO payloads, and notarization. `COVERAGE.md` gives the reason for each.

Two design choices worth knowing:

- The checks come from Apple's own catalog. For each managed setting, MEU names the payload type and key it
  reads, and the generator turns that into a `managed_policies` query. The pass and fail rules are MEU's.
- Network checks use `curl_certificate`, which completes a TLS handshake and reports the TLS version and
  issuer. That covers reachability, MEU 4.8's TLS 1.2 check, and its HTTPS interception check in one
  table. Port 80 hosts use `curl`. Each host and port is tested once, even when MEU lists it twice.


## Known limits

- `curl_certificate` connects directly. It doesn't use the system proxy, so on a network that only allows
  traffic through a proxy, the network reports fail where MEU passes.
- Its timeout bounds reads, not the TCP connect. A firewall that drops packets, rather than refusing them,
  can hold each blocked host for the macOS connect timeout. TEST_PLAN.md T-9 measures this.
- The interception check expects `courier.push.apple.com` to have a certificate issued by Apple Inc.
  Confirm this on a clean network before relying on it (T-7).


## Rebuild for a new MEU release

Download MEU from Apple, install it on a Mac, then:

```bash
python3 testing/mac-eval-utility/tools/build-meu-reports.py "/Applications/Mac Evaluation Utility.app"
python3 testing/mac-eval-utility/tools/sqlite-logic-check.py
python3 .claude/skills/fleet-gitops/scripts/validate.py
```

The generator stops if Apple adds a test it has no mapping for. Add the test to `MANUAL` or
`NOT_COVERED` in the generator, then run it again. Add your own hosts (MEU's Custom Hosts test) with
`--extra-host host:port`.

Apple's catalog is not committed. Only the facts the reports need (test IDs, titles, payload keys, host
names) are in the generated files.
