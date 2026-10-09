# R-1c: current script (IdP email only, company-owned only, asset tags) against the mock

- **Date:** 2026-10-09
- **Objective:** Check the script after the live-test changes, with no real data
- **Expected:** IdP emails only, company-owned statuses only, serial written as asset tag, managed hosts without an email flagged, guard stops a run with no usable email

## Steps and evidence
Same method as R-1: a fake `curl` on `PATH` (`mock/bin/curl`) serves made-up Fleet and Google JSON (`lab.test` emails) and logs
every call. Mock data updated to match the live API: IdP rows use the source `mdm_idp_accounts` (the API reports an admin-set IdP
username that way, confirmed live on 2026-10-09), every host has a serial, plus host 10 (company-owned, custom email only, MANAGED in Google).
Run: `bash run.sh <script>`.

| Case | Seen | Output |
|---|---|---|
| Lint | `shellcheck` and `bash -n` clean | `01` |
| Existing MANAGED state without a serial | `MANAGED -> MANAGED (serial number updated)`, PATCH with `assetTags: ["SER001"]` | `02` |
| New iPad, IdP email | `none -> MANAGED`, `assetTags: ["SER002"]` | `02` |
| Host gone from Fleet | `MANAGED -> UNMANAGED`, `assetTags: []`, `customId: ""` | `02` |
| Custom email only (host 10) | Flagged "No email", Google state `MANAGED -> UNMANAGED` | `02` |
| No email at all (host 7) | Flagged "No email" | `02` |
| BYOD `On (personal)` (host 4) | Not counted by default; counted with `ENROLLMENT_STATUSES` incl. `On (personal)` | `02`, `03` |
| Custom emails allowed (`EMAIL_SOURCES`) | Host 10 matched again, serial filled | `04` |
| Two iPhones for one user | "Review", no write | `02` |
| No iPhone or iPad with MDM on | Guard: exit 1, no writes | `05` |
| iPhones with MDM on, none with an IdP email | "No email" lines, then guard: exit 1, no writes | `06` |
| Summary line on every run | `Fleet: 7 managed iPhones and iPads, 5 with an email from mdm_idp_accounts. Google: 11 ... Changes: 5.` | `02` |

## Result: PASS
