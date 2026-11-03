# Test plan: Mac Evaluation Utility checks as Fleet reports

Issue: none (lab project) · Owner: Adam Baali · Environment: lab Fleet, one Apple silicon Mac on macOS 26 · Started: 2026-11-03

## Scope
Show that the five MEU reports give the same answer as MEU 4.8.1 on the same Mac, for every test they cover.
Find where osquery behaves differently from MEU: proxies, dropped packets, TLS inspection, run time.
Out of scope: the 32 MEU tests listed as not covered in COVERAGE.md.

## Environment
| Item | Value |
| --- | --- |
| Fleet | `https://fleet.mpc.ad`, the reports are global (`default.yml`) |
| Hosts | Apple silicon Mac, macOS 26, enrolled in the lab Fleet. An Intel Mac with T2 for T-11 if one is available |
| Other systems | MEU 4.8.1 on the same Mac. `pf` for blocking hosts. mitmproxy for T-7 |
| Lab differences from production | One Mac, home network, no corporate proxy or firewall |

## Tests
| ID | Test | Steps | Expected | Pass when |
| --- | --- | --- | --- | --- |
| T-1 | Generator is reproducible | 1. Run `build-meu-reports.py` on MEU 4.8.1. 2. `git diff` | No change to the generated files | Diff is empty |
| T-2 | Static and logic checks | 1. `validate.py`. 2. `sqlite-logic-check.py` | No new FAIL. Both fixtures give the expected results | Validator shows only the two FAILs already on `main`; logic check prints PASSED |
| T-3 | Each report runs on a Mac | 1. Merge. 2. Run each report as a live query on the lab Mac. 3. Note row count and time | Rows match README counts, no errors | 13, 62, 7, 145, 103 rows; no osquery error in the host's logs |
| T-4 | Same answers as MEU | 1. Run MEU on the same Mac and export JSON. 2. Export the five reports. 3. Compare by `meu_id` | Every covered test agrees | Each difference is either fixed or written up in RESULTS.md with the reason |
| T-5 | Managed settings are seen | 1. Deliver a test profile with firewall, guest account, screen saver, FileVault escrow, Gatekeeper, Xcode, and software update keys. 2. Re-run the management report | Rows flip from unmanaged to managed | Every key in the profile shows as managed. Any that doesn't is a `managed_policies` gap to record |
| T-6 | Blocked host fails (negative control) | 1. `pf` rule that rejects one Apple host. 2. Run the network report | Only that host's row fails | One FAIL, every other row unchanged |
| T-7 | HTTPS interception | 1. On a clean network, note the issuer of `courier.push.apple.com:443`. 2. Route the Mac through mitmproxy with its CA trusted. 3. Run the push report | Clean: issuer Apple Inc., PASS. Proxy: FAIL | Both observed. If the clean issuer isn't Apple Inc., fix the check |
| T-8 | Proxy-only network | 1. Allow outbound traffic only through an HTTP proxy. 2. Run MEU and the network report | MEU passes, the report fails | Confirms the documented limit. Record it |
| T-9 | Dropped packets | 1. `pf` rule that drops (not rejects) one host. 2. Time the network report. 3. Check that other scheduled reports still run | Runs slower, still finishes | Time per dropped host recorded. If it starves other queries, split or sample the courier hosts |
| T-10 | Application report cost | Run the application report on a Mac with many apps; watch CPU and the osquery watchdog | Finishes without the watchdog killing it | No watchdog denylist entry in the host's logs |
| T-11 | Intel Mac | Run the reports on an Intel Mac with a T2 chip | Secure Enclave PASS, secure boot reads `secure_mode` | Values match MEU on that Mac |

## Out of scope / not tested
- The 32 MEU tests in COVERAGE.md marked not covered.
- Supplemental match domains and service order: osquery doesn't expose them, so those rows are approximations.
- The SHA-1 signature check: a candidate using `codesign.cdhash_sha256` is listed in COVERAGE.md and needs a host to test it.
