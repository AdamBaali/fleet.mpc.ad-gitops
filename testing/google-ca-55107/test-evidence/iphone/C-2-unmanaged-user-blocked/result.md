# C-2: a user Fleet never marked is blocked on the same iPhone

- **Date:** 2026-10-09
- **Objective:** Prove the condition blocks a user without a Fleet state (condition from C-1e)
- **Expected:** "Your organisation isn't allowing access" for the unmanaged test user

## Steps and evidence
- 15:38:20Z Drive > Add another account > the unmanaged test user (same OU, no Fleet host has this email). First sign-in set a password.
- `01` 15:39:18Z "Device info syncing for secure app access. Your device is syncing with your organisation's security settings.
  This might take a few minutes."
- `02` 15:39:27Z **"Your organisation isn't allowing access"**.
- `03` API read: the sign-in created a **second Google device record** for the same phone (15:39:30Z, `osVersion` iOS 18.7 while the
  phone runs 26.6.1; both records share the console "Device ID"). The unmanaged user has **no client states at all**, so
  `device.vendors` is empty and the condition is false. A GET of the Fleet state returns 200 with an empty body, not 404.
- A real sync ran at 15:41Z with both users on the phone: no output, no writes (the script skips users Fleet never marked).
  The managed test user stayed MANAGED.
- The console first showed the new record with user "-" and no Third-party services; the API had the email a few minutes later.

## Result: PASS

What this proves: a user Fleet never marked is blocked, on a phone that is in Fleet. A phone that leaves Fleet is E-2.
Not tested: a second iPhone that was never in Fleet.
