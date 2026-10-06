# Test plan: fleetdm/fleet#54654

Guides under test (PR #54346): `articles/pingfederate-conditional-access-integration.md`,
`articles/require-fleet-managed-hosts-in-duo.md`, the two lines added to
`articles/conditional-access.md`, `docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh`,
`docs/solutions/linux/scripts/import-certificate-to-browsers.sh`.

## Already verified desk-side

- `GET /hosts/identifier/:identifier`, `GET /hosts/:id/health` (`failing_critical_policies_count`,
  Premium only, read live from the database), `populate_policies` on List hosts, and
  `GET /reports/:id/report` all exist.
- Report data is clipped at `report_cap` (default 1,000 rows).
- Duo Desktop is a Fleet-maintained app for macOS and Windows.
- Duo device IDs: Windows MachineGuid, macOS hardware UUID, Linux product UUID. Duo's sync script
  replaces the whole cache on each run.
- The export script passes shellcheck and `tests/test_export_script.sh`.

## PingFederate

| ID | Test | Expected |
| --- | --- | --- |
| P-1 | macOS SCEP profile, `PayloadScope` = `User`, CN = `$FLEET_VAR_HOST_UUID` | Cert in login keychain, CN = host UUID, clientAuth EKU |
| P-2 | Windows SCEP with `./User/` paths | Cert in `Cert:\CurrentUser\My`, CN = host UUID |
| P-3 | Linux cert + `import-certificate-to-browsers.sh` | Visible via `certutil -L -d sql:$HOME/.pki/nssdb` and in Firefox (deb and snap) |
| P-4 | Linux: user who never opened Firefox, and a user created after the import | Probably not covered until a rerun. Confirm, then document |
| P-5 | REST API data store connection test with the Bearer header | Succeeds |
| P-6 | Second attribute source uses `${fleetHostID}` from the first | Works, or find an approach that does |
| P-7 | Managed, passing critical policies (A, B, C in Chrome, Edge, Safari, Firefox) | Sign-in succeeds |
| P-8 | Managed, failing a non-critical policy only | Sign-in succeeds |
| P-9 | Flip the critical policy to fail, refetch, sign in | Denied. Record what the user sees |
| P-10 | Fix it, select **Refetch** on **My device**, sign in | Succeeds within about a minute |
| P-11 | Host D, no cert | Denied |
| P-12 | Valid cert, host deleted from Fleet | Clean denial, not a server error |
| P-13 | New host before its first policy run | Unrun policies don't count as failing, so sign-in succeeds. Decide if the guide should say so |
| P-14 | `AutoSelectCertificateForUrls` for Chrome and Edge | No certificate picker |
| P-15 | Cert renewal | Renewed cert still works; Linux import replaces the old nickname |
| P-16 | Firefox on macOS and Windows | Uses the OS certificate (`security.osclientcerts.autoload`), or note it doesn't |

## Duo

| ID | Test | Expected |
| --- | --- | --- |
| D-1 | Duo Desktop via Fleet-maintained (macOS, Windows) and custom package (Linux), policy automation | Installs and runs |
| D-2 | MachineGuid report | Rows for host B. Time how long a new Windows host takes to appear |
| D-3 | Export script locally | Three CSVs with a `device_id` header |
| L-1 | Each CSV ID vs the ID Duo Desktop reports for A, B, C | Exact match, including case |
| L-2 | Linux VM without a product UUID | Duo uses `/etc/machine-id`, Fleet doesn't. Confirm and document |
| D-4 | `device_cache_sync.py --infile` per OS | Cache count matches the CSV |
| D-5 | Integrations active for the test group, policy blocks untrusted | A, B, C succeed; D denied |
| D-6 | GitHub Actions workflow exactly as in the guide | Record what breaks (no Duo credentials step) |
| D-7 | Enroll a new host, wait for the next sync | Sign-in works after one sync (Windows also waits for the report) |
| D-8 | `REQUIRE_PASSING_CRITICAL_POLICIES=true`, flip the critical policy | Host leaves the cache on the next sync, returns after fix + refetch + sync |
| D-9 | Report fetch fails | Script exits non-zero, nothing uploaded |
| D-10 | Zero hosts returned, or a header-only CSV uploaded | Record what Duo does. Risk: everyone untrusted |
| D-11 | More Windows hosts than `report_cap` | Hosts past the cap silently dropped. Confirm with a lowered cap |
| D-12 | Sync every 5 minutes for a day | No Duo API errors or rate limits (Duo recommends daily) |

## Suspected guide issues to confirm

| Guide | Issue | Proposed edit |
| --- | --- | --- |
| Duo | Workflow never supplies the Duo scripts, which contain keys | Store them as repo secrets; show how |
| Duo | An empty or partial export replaces the whole cache | Temp files, move on success, refuse big drops |
| Duo | Windows report clips at 1,000 rows | Mention `report_cap` |
| Duo | Report interval and keeping data not stated | Add both; new Windows hosts wait for report + sync |
| Duo | Linux VMs without a product UUID | Troubleshooting line |
| Duo | Every 5 minutes vs Duo's daily recommendation | Keep only if D-12 passes |
| Duo | Export script must be executable in the repo | `chmod +x`, or call it with `bash` |
| Ping | Okta Verify example's CN isn't the host UUID | Say to change `SubjectName` |
| Ping | EKU comes from the CA template, not the profile | Reword Step 3 |
| Ping | Linux import covers existing users and Firefox profiles only | Note reruns |
| Ping | New hosts pass before policies first run | Add a note if the team agrees |

## Done when

- Every test has a result, and failures are fixed or documented.
- Both guides were followed start to finish with no guessing.
- Script changes pass shellcheck and the extended test script.
- Adam has reviewed the diff.
