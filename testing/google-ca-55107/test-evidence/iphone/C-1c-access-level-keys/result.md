# C-1c: does the access level read the Fleet client state?

- **Date:** 2026-10-09
- **Objective:** With the state MANAGED/COMPLIANT, find a `device.vendors[...]` key that lets the managed iPhone in
- **Expected:** Drive opens for the managed user

## Steps and evidence (times UTC, condition saved in Admin console > Context-Aware Access > Access levels > Advanced)
| Time | Condition | Result |
|---|---|---|
| 09:00 | `device.vendors["<customer-ID>-fleet"]` (guide) | Blocked (state was under the no-C partner ID) |
| 09:05 | `device.vendors["<id-without-C>-fleet"]` | Blocked on retries; no new log entry (Drive replayed the old denial) |
| 09:33 | OR of 4 keys (`<id-without-C>-fleet`, `fleet`, `key-<id-without-C>`, `<customer-ID>-fleet`) | 10:45 log: Denied. Unclear: the condition box was later seen empty |
| 10:59 | **`device.is_admin_approved_device == true`** (no Fleet data, diagnostic) | **11:00:51 "Access evaluated", satisfied; Drive opened** (`01`) |
| 11:08 | `device.vendors["fleet"].is_managed_device == true` | **Blocked again within seconds** (`02`), live re-evaluation |
| 11:20 | literal placeholder text (operator error) | Blocked (`03`), not a valid test |
| 11:28 | `device.vendors["<id-without-C>-fleet"].is_managed_device == true` | **11:44:21 "Access Denied"**, unsatisfied |

- The access level, the test OU assignment, the licences and the phone all work: a condition on data Google has passes, and Drive opens.
- Both key forms the docs point to fail while Google's own console shows the state as Managed and Compliant.
- Assignment scope found and fixed during the test: the level had been assigned at the top-level OU for Admin Console, Drive and Gmail (lockout risk). Moved to the test OU only (Drive and Gmail).
| 12:11 | `device.vendors["key-<id-without-C>"]` (Google spec) | Blocked |
| 12:14 to 12:39 | OR of 3 keys, then 6 terms with `is_compliant_device` (text verified) | Blocked, no log row |
| 12:39 | `device.vendors["fleet-<id-without-C>"]` managed or compliant (PR fleetdm/fleet#46454) | **12:44:34 Access Denied**, state MANAGED for 99 minutes |

- Delay ruled out (99 minutes). Third-party integrations offer only BeyondCorp Alliance partners, nothing to enable for a custom state.

Screenshots:
- `01` Drive open with the diagnostic condition; `02` blocked again with `device.vendors["fleet"]`; `03` blocked (placeholder test).
- `04` condition with the no-C key; `05` OR of 3 keys (text verified); `06` 6 terms (3 keys x managed/compliant), saved.
- `07` assignment at the top-level OU: 0 everywhere (after the fix); `08` test OU: Drive and Docs, Gmail "1 active applied", Admin Console 0.
- `09` Third-party integrations at the test OU: "Enable BeyondCorp Alliance partner services: None"; `10` Manage partner connections: Lookout, Checkpoint, Omnissa, Jamf, CrowdStrike, Ivanti, Intune, Citrix. No custom option.

## Result: FAIL
