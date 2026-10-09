# Results: Google conditional access for iPhones (fleetdm/fleet#55107)
Scope: the interim workaround in PR fleetdm/fleet#55107 (guide + sync script + GitHub Action). Built-in support is
fleetdm/fleet#54888. Evidence: `test-evidence/<group>/<ID>-<slug>/`.

| ID | Result | One line |
|---|---|---|
| R-1 | PASS | `bash -n` and `shellcheck` clean. Mock run: 12 of 14 cases as expected, 2 findings (old iPhone in Google blocks the new one; failed write stops the run) |
| R-1b | PASS | Proposed script (partner ID without C, empty-list guard): lint clean, exits 1 with no changes when Fleet returns 0 hosts |
| R-2 | PASS | Fleet 4.92 docs and code: `device_mapping=true` on List hosts, statuses "On (manual)" and "On (automatic)" |
| R-3 | PASS | Live: partner ID must be **without the leading C**, and `customer=` must be `customers/my_customer` (E-14) |
| R-4 | NOT-RUN | `device.vendors` Preview status not found on Google's CAA pages. Vendor key format differs between pages (`<id>-suffix` vs `key-<id>`): test live |
| R-5 | PASS | Read in full with R-1. Paging, exit codes, idempotency OK |
| R-6 | NOT-RUN | Wording pass after the live test |
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
| C-1c | FAIL | Access level never satisfied by the Fleet state (`fleet` and `<id-without-C>-fleet` keys); a non-Fleet diagnostic condition lets Drive open. Delay re-check pending |
| C-1d | INFO | Context-Aware Access log: 3 denials, 1 allow (diagnostic) |
| C-2 to C-4, E-1 to E-10, E-12, G-12 | NOT-RUN | Blocked on C-1c |

## Findings so far (desk)
1. **Old iPhone left in Google blocks the new one.** One Fleet host plus two Google iPhones for the same user is
   ambiguous, so neither is marked managed. Common when people upgrade phones. Guide: tell admins to delete the old
   device in Google Admin (Troubleshooting). Evidence: `R-1-script-mock/03-old-iphone-in-google.txt`.
2. **Customer ID format.** Google: partner ID is `{customer}-suffix`, using the ID after the leading "C". Guide says
   copy "Customer ID" from Account settings. Confirm in the live org what that shows.
3. **No way to get a token for DRY_RUN.** The guide doesn't say how. Lab helper: `google-token.sh`.
4. **Any email source counts**, including an admin-set custom email. Worth one line.
5. **A failed Google write stops the run** (exit 22), earlier writes kept. The Action shows red, the next run carries on.

## Live findings (2026-10-09)
See [TESTING-LOG.md](TESTING-LOG.md) for the full timeline.
6. **Script bug: partner ID.** Must be the customer ID without the leading C.
7. **Script bug: customer parameter.** `customers/<customer-ID>` returns 400 for the delegated caller; use `customers/my_customer`.
8. **Workflow bug.** `google-github-actions/auth@v2` with `access_token_subject` returns HTTP 400 `invalid_request`; signing the JWT in the job works.
9. **The access level doesn't read the Fleet state** with either documented key, while the state is MANAGED and shown in the console. Blocker for the guide; question open with Google.
10. **Assignment scope.** Assigning at the top-level OU includes Admin Console and the admin: lockout risk. The guide should say to pick the test OU and not Admin Console.
11. **Retries replay the old block.** After the sync, the Drive app kept showing the earlier denial; Google only re-evaluated on a fresh sign-in or a condition change.
