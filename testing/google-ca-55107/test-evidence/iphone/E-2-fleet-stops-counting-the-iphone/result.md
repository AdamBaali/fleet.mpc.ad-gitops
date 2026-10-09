# E-2: when Fleet stops counting the iPhone, the sync blocks it; when Fleet counts it again, it opens

- **Date:** 2026-10-09
- **Objective:** Prove the condition from C-1e follows Fleet's state end to end (Fleet -> GitHub Action -> Google -> sign-in)
- **Expected:** T1 UNMANAGED, T2 blocked, T4 MANAGED, T5 Drive opens

## Steps and evidence
- How Fleet "stops counting" the phone: its custom end user email is changed to a dummy, so the script no longer matches it to the
  managed test user. Deleting or unenrolling the host doesn't work in this lab: it's the only managed iPhone, so the script's
  empty-Fleet guard stops the run and Google keeps MANAGED (finding 26 in GUIDE-FINDINGS.md).
- `01` T0 15:42:19Z email changed. T1 run 37953743223 (manual, real): `(managed-test@…/iphone): MANAGED -> UNMANAGED`, read back
  UNMANAGED / NON_COMPLIANT at 15:42:48Z.
- `02` Admin console > device > Third-party services: fleet (custom), **Unmanaged, Non-compliant**, last updated 17:42 local (15:42Z),
  Asset tags "-".
- T2 to T5 were not run on this path: the script moved to IdP emails only, so the full loop was rerun on the IdP path as **E-2b**.

## Result: INFO

First attempt (custom email path), T0 and T1 only. Superseded by E-2b, which passed.
