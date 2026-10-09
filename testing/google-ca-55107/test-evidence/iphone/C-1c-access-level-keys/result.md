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
- Not yet ruled out: a delay. The state is MANAGED continuously from 11:05:42 (a reset for C-1b). Google documents a 90 minute delay for CrowdStrike signals. Re-check after 12:40.

## Result: FAIL
