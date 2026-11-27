# Test plan: package filename versus contents when adding a version

Request: customer-cisneros-l (link in `private/`) · Owner: Adam · Environment: lab Fleet, Package Identity Lab fleet · Started: 2026-11-27

## Scope
This covers adding a package to an existing title through the API call the UI's "Add package" button sends
(`POST /api/v1/fleet/software/package` with `software_title_id`). It checks which title Fleet picks and which
message it returns when only the filename changes, for script and .tar.gz packages.

No host install is needed. The tests stop at the upload, where the error happens.

## Environment
| Item | Value |
|---|---|
| Fleet | `https://fleet.mpc.ad`, 4.95.0 on 2026-11-27, Premium |
| Fleet under test | Package Identity Lab (`fleets/package-identity-lab.yml`) |
| Base package | `lib/linux/software/package-identity-probe.sh`, title `package-identity-probe` |
| Lab differences from production | The customer's real package type is not confirmed (see NOTES.md) |

## Tests
| ID | Test | Steps | Expected | Pass when |
|---|---|---|---|---|
| T-0 | Lab setup | Read the version, the fleet ID and the base title ID | Fleet 4.90 or later, one package on the title | The title has the base SHA-256 |
| T-1 | Same name, same bytes | Upload the base file to its title | 409 "package-identity-probe.sh package is already added (same SHA-256 hash)." | Status and message match |
| T-2 | New name, same bytes | Upload the base bytes as `package-identity-probe-test.sh` to the title | Today: 400 title mismatch. Asked for: the hash conflict message | Records which message Fleet returns |
| T-3 | New name, new bytes | Upload v2 bytes as `package-identity-probe-v2.sh` to the title | Today: 400 title mismatch. Asked for: 200 | Records whether the title gets a second package |
| T-4 | Same name, new bytes | Upload v2 bytes as `package-identity-probe.sh` to the title | 200, a second package on the title | Status 200 and the title lists two packages |
| T-5 | .tar.gz base title | Upload `probe-tool.tar.gz` as a new title | 200, title `probe-tool.tar.gz` | Title exists |
| T-6 | .tar.gz new name, new bytes | Upload `probe-tool-test.tar.gz` to the T-5 title | Today: 400 title mismatch. Asked for: 200 | Records the status |

Run them all with `bash scripts/run-tests.sh` from this folder. It needs `private/fleet.env` with `FLEET_URL` and
`FLEET_API_TOKEN`.

## Out of scope / not tested
- .deb and .rpm renames. Their title comes from package metadata, so the filename doesn't decide it (code read).
  Add a test if the customer's package turns out to be one of these.
- The separate GitOps 409 problem the customer raised on the same call. It is a support question, not this request.
- GitOps. In GitOps a package has no `software_title_id`, so a renamed script becomes its own title without an error.
