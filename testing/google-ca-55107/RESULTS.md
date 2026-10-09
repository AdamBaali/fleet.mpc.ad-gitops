# Results: Google conditional access for iPhones (fleetdm/fleet#55107)
Scope: the interim workaround in PR fleetdm/fleet#55107 (guide + sync script + GitHub Action). Built-in support is
fleetdm/fleet#54888. Evidence: `test-evidence/<group>/<ID>-<slug>/`.

| ID | Result | One line |
|---|---|---|
| R-1 | PASS | `bash -n` and `shellcheck` clean. Mock run: 12 of 14 cases as expected, 2 findings (old iPhone in Google blocks the new one; failed write stops the run) |
| R-1b | PASS | Proposed script (partner ID without C, empty-list guard): lint clean, exits 1 with no changes when Fleet returns 0 hosts |
| R-2 | PASS | Fleet 4.92 docs and code: `device_mapping=true` on List hosts, statuses "On (manual)" and "On (automatic)" |
| R-3 | PARTIAL | Google reference says the partner ID uses the customer ID **without the leading C** (confirmed on two Google pages). Live test pending (E-14) |
| R-4 | NOT-RUN | `device.vendors` Preview status not found on Google's CAA pages. Vendor key format differs between pages (`<id>-suffix` vs `key-<id>`): test live |
| R-5 | PASS | Read in full with R-1. Paging, exit codes, idempotency OK |
| R-6 | NOT-RUN | Wording pass after the live test |
| G-1 | PASS | Org, OU, primary domain verified, iOS mobile management Basic |
| G-1b | PASS | Business Plus has no Context-Aware Access; Enterprise Standard has it ("ON for everyone") |
| G-1c | PASS | Test users created and moved to the test OU |
| G-2/G-3 | PASS | Project, Cloud Identity API, service account; delegation active after the admin added it (first try `unauthorized_client`); devices API reachable, 0 devices |
| G-2/G-4 | PASS | API-only Observer Fleet user; guide script DRY_RUN exits 0 (0 devices) |
| G-5 to G-7 | NOT-RUN | Need the iPhone (enroll, Google sign-in, workflow) |
| G-8 | PARTIAL | Access level created (Advanced CEL accepted); assignment to Drive and Gmail done by the admin; OU-level state to confirm (lockout risk), may need the partner ID fix |
| C-1 to C-4, E-*, G-12 | NOT-RUN | Waiting on the iPhone |

## Findings so far (desk)
1. **Old iPhone left in Google blocks the new one.** One Fleet host plus two Google iPhones for the same user is
   ambiguous, so neither is marked managed. Common when people upgrade phones. Guide: tell admins to delete the old
   device in Google Admin (Troubleshooting). Evidence: `R-1-script-mock/03-old-iphone-in-google.txt`.
2. **Customer ID format.** Google: partner ID is `{customer}-suffix`, using the ID after the leading "C". Guide says
   copy "Customer ID" from Account settings. Confirm in the live org what that shows.
3. **No way to get a token for DRY_RUN.** The guide doesn't say how. Lab helper: `google-token.sh`.
4. **Any email source counts**, including an admin-set custom email. Worth one line.
5. **A failed Google write stops the run** (exit 22), earlier writes kept. The Action shows red, the next run carries on.
