# Acceptance checklist: does the test meet the issue's criteria?
From the request: (1) follow the guide with a test iPhone and a test OU, (2) confirm an iPhone in Fleet can sign in and an iPhone not
in Fleet is blocked, (3) report what worked and what didn't, and update the guide.

| # | Criterion | Test IDs | Status |
| --- | --- | --- | --- |
| A1 | Google org on a supported edition, test OU exists | G-1, G-8 | DONE (Enterprise Standard trial, OU Fleet iOS test) |
| A2 | Access level created with the guide's condition | G-8 | DONE |
| A3 | Access level assigned to the test OU only, Active | G-8 | **Adam to verify: Admin Console / MPC top level showed "1 active applied" (lockout risk)** |
| A4 | Two test users in the OU (managed, unmanaged) | G-1 | DONE (moved to Fleet iOS test) |
| A5 | Fleet fleet "iOS Google Lab" + iPhone enrolled in Fleet with the user's email | G-5 | Fleet file ready (local commit), secret and push needed, iPhone not enrolled |
| A6 | Google service account, delegation, API user (guide Step 1 and 2) | G-2, G-3 | DONE (key, delegation active, API-only Fleet user) |
| A7 | Sync script DRY_RUN then live, scheduled workflow | G-4, G-7 | Lint and DRY_RUN done (exit 0, 0 devices). Live run needs an iPhone signed in |
| A8 | Fleet-managed iPhone signs in (C-1) with live screen recording + screenshots | C-1 | Not run |
| A9 | Unmanaged iPhone blocked (C-2), the block message captured | C-2 | Not run |
| A10 | Drive and Google app too (C-3), iPad if available (C-4) | C-3, C-4 | Not run |
| A11 | Report: what worked and what didn't, guide edits drafted as a diff | GUIDE-FINDINGS | In progress (6 findings so far) |
| A12 | Evidence: .mov + window-only PNGs per test, masked emails, index built | `_framework` | In progress |
Mirroring: AirPlay Receiver is ON on this Mac (port 7000 listening). Check iPhone and Mac are on the same network. Capture: `tools/ios-shot.sh <out.png>`.
