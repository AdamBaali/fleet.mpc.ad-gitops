# Package filename versus contents when adding a version

customer-cisneros-l adds a new package to an existing software title and gets
"Couldn't add. <file> doesn't match the software title." when only the filename differs.
They ask Fleet to decide by contents (SHA-256), not by filename. This project shows where the
filename matters, and gives a lab fleet to reproduce it.

**Status:** 2026-11-27. Code read at `fleet-v4.95.0` (the lab) and `fleet-v4.96.0`. Lab run not done yet.

## What we found (code read)
- Fleet decides which title a new package belongs to from the package's identity: bundle ID (.pkg, .ipa),
  upgrade code (.msi), else the name it extracts from the package metadata (.deb, .rpm, .exe).
- Packages without metadata use the filename as that name. Script packages (.sh, .ps1, .py) and .zip use the
  filename without the extension. .tar.gz uses the whole filename. So for these types a rename is a new title.
- When the admin adds a package to a title (`software_title_id`), Fleet rejects any package whose identity
  doesn't resolve to that title. This check landed in 4.90.0. Before it, the package made a new title.
- The title check runs before the duplicate hash check. A renamed file with identical bytes gets the title
  mismatch message, not "already added (same SHA-256 hash)". That is the misleading message in the request.
- A .deb or .rpm renamed on disk keeps its title, because its name comes from the package metadata.

## Files
| File | What |
|---|---|
| [TEST_PLAN.md](TEST_PLAN.md) | The tests and how they pass |
| [RESULTS.md](RESULTS.md) | One entry per test |
| [NOTES.md](NOTES.md) | Code references at the release tags, lab versus production |
| [HANDOFF.md](HANDOFF.md) | State, next steps, teardown |
| [scripts/run-tests.sh](scripts/run-tests.sh) | Runs every test against the lab fleet and saves evidence |
| [scripts/upload.sh](scripts/upload.sh) | One upload, the same request as "Add package" on a title page |
| [drafts/feature-request.md](drafts/feature-request.md) | Draft of the feature request for fleetdm/fleet |
| `../../fleets/package-identity-lab.yml` | The lab fleet: one script package as the base title |
