# Results: Google conditional access for iPhones (fleetdm/fleet#55107)
Scope: the interim workaround in PR fleetdm/fleet#55107 (guide + sync script + GitHub Action). Built-in support is
fleetdm/fleet#54888. Evidence: `test-evidence/<group>/<ID>-<slug>/`.

| ID | Result | One line |
|---|---|---|
| R-1 | PASS | `bash -n` and `shellcheck` clean. Mock run: 12 of 14 cases as expected, 2 findings (old iPhone in Google blocks the new one; failed write stops the run) |
| R-1c | PASS | Current script on the mock: IdP emails only, company-owned only, serial as asset tag, "No email" flags, guard exits 1 with no writes |
| R-1b | PASS | Proposed script (partner ID without C, empty-list guard): lint clean, exits 1 with no changes when Fleet returns 0 hosts |
| R-2 | PASS | Fleet 4.92 docs and code: `device_mapping=true` on List hosts, statuses "On (manual)" and "On (automatic)" |
| R-3 | PASS | Live: partner ID must be **without the leading C**, and `customer=` must be `customers/my_customer` (E-14) |
| R-4 | INFO | Settled live: the partner ID has no leading C (C-1b); no named `device.vendors` key works on iOS (C-1c); the keyless `exists()` does (C-1e) |
| R-5 | PASS | Read in full with R-1. Paging, exit codes, idempotency OK |
| R-6 | PASS | Guide edits checked against Fleet's `handbook/company/writing.md` and guide formatting rules, and the PingFederate and Duo guides |
| G-1 | PASS | Org, OU, primary domain verified, iOS mobile management Basic |
| G-1b | PASS | Business Plus has no Context-Aware Access; Enterprise Standard has it ("ON for everyone") |
| G-1c | PASS | Test users created and moved to the test OU |
| G-2/G-3 | PASS | Project, Cloud Identity API, service account; delegation active after the admin added it (first try `unauthorized_client`); devices API reachable, 0 devices |
| G-2/G-4 | PASS | API-only Observer Fleet user; guide script DRY_RUN exits 0 (0 devices) |
| G-5 | PASS | iPhone enrolled (`On (manual)`, page defaulted to Company-owned); email set as a custom mapping (deviation) |
| G-6 | PASS | Drive sign-in adds the device to Google; blocked before the sync, as expected |
| G-7 | PARTIAL | GitHub Action fails as written (auth action DWD token HTTP 400); works with a JWT step in the job |
| G-8 | PASS | Access level created; assignment found at the top-level OU (lockout risk) and moved to the test OU only (Drive, Gmail) |
| C-1a | FAIL | PR script as written: HTTP 400 on the first write (two bugs) |
| C-1b | PASS | Fixed script writes MANAGED/COMPLIANT; console shows "fleet (custom)"; second run no-op (E-11) |
| C-1c | FAIL | No named key works (`fleet`, `<id-without-C>-fleet`, `key-<id>`, `fleet-<id>`, `C<id>`, `<id>`); a non-Fleet diagnostic condition lets Drive open. Not a delay (99 min) |
| C-1d | INFO | Context-Aware Access log: 3 denials, 1 allow (diagnostic) |
| C-1e | PASS | Keyless `device.vendors.exists(k, device.vendors[k].is_managed_device == true)`: managed user opens Drive (13:51, B-0 15:31) |
| C-2 | PASS | Unmanaged user on the same iPhone: "Your organisation isn't allowing access"; no client state for that user |
| E-2 | INFO | First attempt on the custom-email path (T0, T1); superseded by E-2b |
| E-2b | PASS | IdP path, script defaults, GitHub Action: open; guard stops a no-email run; blocked within seconds; back in after "Please sign in again" |
| G-2b | PASS | Sync token limited to List hosts (`PATCH /users/api_only/:id`) |
| C-3, C-4, E-3, E-7, E-12, G-12 | NOT-RUN | Safari, iPad, unenroll, a user outside the OU, wipe and re-enroll, the schedule over hours |

Findings, in guide order and with what the branch fixes: [GUIDE-FINDINGS.md](GUIDE-FINDINGS.md). Timeline: [TESTING-LOG.md](TESTING-LOG.md).
