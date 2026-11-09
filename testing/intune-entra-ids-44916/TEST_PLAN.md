# Test plan: Intune and Entra device IDs on Windows hosts

Issue: fleetdm/fleet#44916 (folded into fleetdm/fleet#43723) · Customer: `customer-cisneros-w` · Started: 2026-11-09

## Scope

Prove that stored reports give each Windows host's Intune device ID and Entra device ID, correctly, through the API.
Covers the SQL in `queries/`, report storage and the API calls from the walkthrough already sent to the customer.
Doesn't cover adding the IDs to the host API itself. That is a product change, not a test (see [NOTES.md](NOTES.md)).

## Environment

| Item | Value |
| --- | --- |
| Fleet | Lab Fleet `https://fleet.mpc.ad`, Premium. Version to record on test day. Customer runs 4.93 or later |
| Hosts | Lab Windows 11 VM on QEMU (`../_framework/vm/`), fleetd agent-only |
| Other systems | None. No Entra or Intune tenant |
| Lab differences from production | Registry keys and certificates are faked in T-1 and T-2. Windows didn't write them |

## Tests

| ID | Test | Steps | Expected | Pass when |
| --- | --- | --- | --- | --- |
| T-1 | Query logic on faked data | 1. On the VM, create `Enrollments\<guid>\DMClient\MS DM Server\EntDMID`. 2. Create a CA with subject `DC=net + DC=windows + CN=MS-Organization-Access + OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97`, and a leaf in `LocalMachine\My` with `CN=<test GUID>`. 3. Create `JoinInfo\<leaf thumbprint>` with `TenantId` and `UserEmail`. 4. Live query both files in `queries/` | Each query returns the faked ID | Values match what was written, character for character. Record whether `common_name` or `subject` holds the bare GUID |
| T-2 | Negative controls | Re-run after each change: a. delete all fakes; b. `JoinInfo` subkey with no matching certificate; c. leaf certificate from a different issuer; d. a second, older `Enrollments` key with another `EntDMID` | a. no rows; b. no row; c. no row; d. two Intune rows, each with its key | Each control changes the result as expected. If one doesn't, the query is wrong |
| T-3 | Stored report and API | 1. Add both queries as reports with `interval` set and `discard_data: false` in a lab fleet. 2. Wait for results. 3. `GET /api/v1/fleet/reports/:id/report?page=0&per_page=500`. 4. `GET /api/v1/fleet/hosts/:id/reports/:id` | One row per host with `host_id`, `last_fetched` and the ID columns | Rows match T-1. `report_clipped` is `false` |
| T-4 | Real host values | On an Entra-joined, Intune-enrolled host: run both queries, `dsregcmd /status`, and look up the device in the Intune and Entra portals | Entra ID equals `DeviceId` from dsregcmd and the Entra portal. Intune ID equals the Intune portal's Device ID | Both match. BLOCKED: needs a tenant |
| T-5 | Re-image stability | Re-image the T-4 host with Autopilot, then re-run | New IDs, and no stale Intune row, or the stale row is identifiable by its key | Results tell the old record from the new one. BLOCKED: needs a tenant |

## Out of scope / not tested

- Hybrid joined hosts (on-premises AD plus Entra). The customer's hosts are Entra joined. Worth one run in T-4 if a hybrid host is at hand.
- Performance. osquery's `certificates` table walks every store regardless of `WHERE` (comment in Fleet's `queries.go`). The `registry` side runs first. Check the report's runtime in T-3.
- Adding the IDs to `GET /hosts/:id`. Raise with product: Fleet already collects the Entra ID for conditional access.
