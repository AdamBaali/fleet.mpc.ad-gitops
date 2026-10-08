# Results: Google conditional access for iPhones (fleetdm/fleet#55107)
Scope: the interim workaround in PR fleetdm/fleet#55107 (guide + sync script + GitHub Action). Built-in support is
fleetdm/fleet#54888. Evidence: `test-evidence/<group>/<ID>-<slug>/`.

| ID | Result | One line |
|---|---|---|
| R-1 | PASS | `bash -n` and `shellcheck` clean. Mock run: 12 of 14 cases as expected, 2 findings (old iPhone in Google blocks the new one; failed write stops the run) |
| R-2 | PASS | Fleet 4.92 docs and code: `device_mapping=true` on List hosts, sources `mdm_idp_accounts`/`idp`/`custom`/`google_chrome_profiles`. Statuses "On (manual)", "On (automatic)", "On (personal)", "On (manual - personal)" all start with "On" |
| R-3 | PARTIAL | `clientStates.patch` path, scope, editions and `pageSize` 100 match. Open: customer ID "C" prefix in the partner ID, `deviceType`/`model` values, PATCH creating a new state, long-running Operation |
| R-4 | NOT-RUN | `device.vendors` Preview status not found yet on Google's CAA pages |
| R-5 | PASS | Read in full with R-1. Paging, exit codes, idempotency OK. See R-1 findings |
| R-6 | NOT-RUN | Wording pass after the live test |
| G-1 to G-8, C-*, E-* | NOT-RUN | Waiting on the Google test org and a test iPhone |

## Findings so far (desk)
1. **Old iPhone left in Google blocks the new one.** One Fleet host plus two Google iPhones for the same user is
   ambiguous, so neither is marked managed. Common when people upgrade phones. Guide: tell admins to delete the old
   device in Google Admin (Troubleshooting). Evidence: `R-1-script-mock/03-old-iphone-in-google.txt`.
2. **Customer ID format.** Google: partner ID is `{customer}-suffix`, using the ID after the leading "C". Guide says
   copy "Customer ID" from Account settings. Confirm in the live org what that shows.
3. **No way to get a token for DRY_RUN.** The guide doesn't say how. Lab helper: `google-token.sh`.
4. **Any email source counts**, including an admin-set custom email. Worth one line.
5. **A failed Google write stops the run** (exit 22), earlier writes kept. The Action shows red, the next run carries on.
