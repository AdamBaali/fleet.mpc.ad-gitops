# C-1d: Context-Aware Access log events for the managed test user

- **Date:** 2026-10-09
- **Objective:** Read Google's own decision and reason for each sign-in
- **Expected:** Denied before the sync, allowed after

## Steps and evidence
- Exported from Security > Context-Aware Access > Assign access levels > Drive and Docs > Actions > View logs (Investigation tool). IPs, device ID and user masked.

| Time (UTC) | Event | Access level satisfied | Unsatisfied | Device state |
|---|---|---|---|---|
| 08:58:28 | Access Denied | | Fleet managed iOS | Normal |
| 10:45:23 | Access Denied | | Fleet managed iOS | Normal |
| 11:00:51 | Access evaluated | Fleet managed iOS | | No Device Signals |
| 11:44:21 | Access Denied | | Fleet managed iOS | Normal |
| 12:09:06 | Access Denied | | Fleet managed iOS | Normal |
| 12:44:34 | Access Denied | | Fleet managed iOS | Normal |

- Only fresh sign-ins and token requests are logged. Retries that replay an old block, and the live re-block at 11:08, don't appear.
- The Reporting > Audit page said the report "isn't available" for this trial domain; the Investigation tool worked.
- 12:09:06 and 12:44:34 rows added from later exports (both Access Denied; 12:44:34 is the suffix-first key, 99 minutes after the write).
- Screenshots: `02` Investigation tool results (Context-aware access log events, filtered to the test OU and Drive); `03` the filter; `04` the device's "fleet (custom)" state (Managed, Compliant) seen during the denials.

## Result: INFO
