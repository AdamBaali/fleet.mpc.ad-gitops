# Mac readiness reports

Fleet reports that check whether each Mac, and the network it sits on, is ready for managed deployment:
device management enrollment, security settings, Apple service reachability, and app compatibility.
They run on every Mac in the lab once a day and keep the results in Fleet.

Status: built and checked without a Mac. Not yet run on a host.


## What's here

| Path | What it is |
| --- | --- |
| `../../lib/macos/reports/mac-readiness.reports.yml` | The five Fleet reports. Generated. `default.yml` references it, so it runs on every Mac in the lab |
| `tools/sqlite-logic-check.py` | Runs every report against a compliant and a non-compliant fixture host in SQLite |
| `TEST_PLAN.md` | What still has to run on a real Mac |
| `HANDOFF.md` | Where the work stands and what to do next |
| `private/` | The generator and the source mapping. Git ignores it. Ask Adam for a copy |


## The reports

| Report | Covers | Rows per host |
| --- | --- | --- |
| Mac readiness - Computer and network (macOS) | Model, macOS version, Secure Enclave, DNS, IP address, hosts file, proxy, Wi-Fi | 13 |
| Mac readiness - Management and identity (macOS) | Enrollment, security settings, Apple Intelligence and software update restrictions, directory binding | 62 |
| Mac readiness - Applications (macOS) | Unsigned and Intel-only apps, kernel and system extensions, background items | 7 |
| Mac readiness - Apple network services (macOS) | Apple service hosts for enrollment, updates, App Store, iCloud, certificates, and more | 144 |
| Mac readiness - Push notifications (macOS) | APNs courier hosts on ports 443 and 5223, HTTPS interception | 103 |

Every report returns the same five columns:

| Column | Meaning |
| --- | --- |
| `check_id` | Stable ID for the check, such as `management.firewall-configuration` or `apple-services.gdmf-apple-com-443` |
| `category` | The area the check belongs to |
| `test` | What the check looks at |
| `result` | `PASS`, `WARN`, `FAIL`, or `INFO` |
| `value` | What the host returned |


## How the checks work

- Managed settings come from `managed_policies`: the payload type and key each setting lives in.
- Network checks use `curl_certificate`, which completes a TLS handshake and reports the TLS version and
  issuer. That covers reachability, TLS 1.2 or later, and HTTPS interception in one table. The host list
  follows Apple's [Use Apple products on enterprise networks](https://support.apple.com/101555).
  Port 80 hosts use `curl`. Each host and port is tested once.
- Some checks have no osquery source: Bonjour, NTP and SFTP reachability, Touch ID enrollment, bootstrap
  token, volume ownership, single sign-on extensions, and notarization. The reports leave them out.


## Known limits

- `curl_certificate` connects directly. It doesn't use the system proxy, so on a network that only allows
  traffic through a proxy, the network reports fail.
- Its timeout bounds reads, not the TCP connect. A firewall that drops packets, rather than refusing them,
  can hold each blocked host for the macOS connect timeout. TEST_PLAN.md T-9 measures this.
- The interception check expects `courier.push.apple.com` to have a certificate issued by Apple Inc.
  Confirm this on a clean network before relying on it (T-7).


## Change the reports

The reports file is generated. Change the generator in `private/`, then run:

```bash
python3 testing/mac-readiness/tools/sqlite-logic-check.py
python3 .claude/skills/fleet-gitops/scripts/validate.py
```
