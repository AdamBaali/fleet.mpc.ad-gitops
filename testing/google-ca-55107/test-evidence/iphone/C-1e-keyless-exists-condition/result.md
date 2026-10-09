# C-1e: keyless exists() condition lets the Fleet-managed iPhone in

- **Date:** 2026-10-09
- **Objective:** Find an access level condition that reads the Fleet client state on the iPhone (every named key failed in C-1c)
- **Expected:** With the state MANAGED, the managed test user opens Drive after a fresh sign-in

## Steps and evidence
- 13:45Z `size(device.vendors) > 0`: Drive opened. The access level does see vendor data on this iPhone.
- 13:47Z `device.vendors.exists(k, device.vendors[k].is_managed_device == true)` saved; 13:51Z Drive opened after sign-out and sign-in.
  Fleet's `MANAGED` is read as `is_managed_device`. Only the key name was the problem.
- 13:53Z and 14:54Z: Google rejects `contains` and list literals inside `exists()` ("not allowed in comprehensions"), so the key can't be
  searched for. 14:59Z the customer ID alone as the key (`C<id>`, `<id>`, guarded with `in`) was blocked.
- `01`: the saved condition (re-checked 15:29Z).
- `02`: B-0 baseline, 15:30:55Z to 15:31:40Z: managed test user removed from Drive, signed in again, **Drive home opens** (state MANAGED).

## Result: PASS

Caveat: the condition trusts any third-party client state that says managed. Fine when Fleet is the only one writing states;
with another integration (for example a BeyondCorp partner), that partner's state would also let a device in.
