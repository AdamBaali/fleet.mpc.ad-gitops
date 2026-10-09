# E-2b: Fleet's IdP email decides access, end to end (managed, guard, blocked, back)

- **Date:** 2026-10-09
- **Objective:** Run the whole loop the way the customer will: the phone's email comes from the IdP (`mdm_idp_accounts`), the script
  uses its defaults (IdP email only, company-owned only), and the GitHub Action writes Google's state
- **Expected:** R1 opens, R2 the guard stops the run, R3 blocked, R4 opens

## Steps and evidence
Setup: the lab phone has no end user authentication, so its IdP username is set by API (`PUT /hosts/14/device_mapping` with
`source: idp`). The API reports it as `mdm_idp_accounts`, the same source end user authentication fills. Its old custom email is a
dummy, which the script ignores by default. Sync token: List hosts only (G-2b). Condition: the keyless `exists()` (C-1e).

| Step | Fleet change | Action run | Google state | Phone |
|---|---|---|---|---|
| R1 | IdP username = managed user | 37958238367 `UNMANAGED -> MANAGED` | Managed, ID 14, **serial as asset tag** (`02`, masked) | Drive opens (`01`) |
| R2 | IdP username removed (the only phone) | 37958816632 **fails**: "No email: Fleet host 14 …", then the guard, exit 1 | Unchanged (Managed) | — |
| R3 | IdP username = dummy | 37958879156 `MANAGED -> UNMANAGED` (16:24:36.7Z) | Unmanaged | Open Drive replaced by **"Your organisation isn't allowing access"** within seconds, no sign-in (`03`, `04`) |
| R4 | IdP username = managed user | 37959301486 `UNMANAGED -> MANAGED` (16:28:07Z) | Managed | Within seconds: **"Please sign in again. Close this message, then sign in to Google Drive or another Workspace app to finalise security checks."** (`05`). Closed it, reopened Drive: **opens** (`06`) |

Raw output: `07-run.txt`. Frames are window-only captures of iPhone Mirroring; frames showing personal accounts or the home screen were removed.

## Result: PASS

What this adds to C-1e and C-2: access follows Fleet's state in both directions, through the GitHub Action, in seconds. Blocking is
live; getting back in needs the user to close the message and reopen the app (no password). With one phone, removing its only email
can't unmanage it: the guard stops the run and the Action shows a failure (finding 26).
Not tested: ADE enrollment with end user authentication on the iPhone (the IdP username was set by API), iPads, BYOD.
