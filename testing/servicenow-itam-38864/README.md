# Host and software fields for a Fleet to ServiceNow ITAM export (fleetdm/fleet#38864)

Tests every host and software field the issue lists, on macOS, Windows and Linux, as a stopgap until Fleet exports them itself. Focus: install date and publisher (#54912, #54914), which Fleet doesn't return yet. Two collection paths: Fleet's built-in APIs and native osquery reports. Nothing is installed on hosts beyond fleetd. Same method as `../_framework`. Work in progress.

| File or folder | What it is |
| --- | --- |
| [TEST_PLAN.md](TEST_PLAN.md) | Every test, how it runs and how it passes |
| [NOTES.md](NOTES.md) | What each OS can give, why no extension, exporter design, risks |
| [RESULTS.md](RESULTS.md) | Ground truth summary and one entry per test |
| [HANDOFF.md](HANDOFF.md) | State, run order, teardown |
| `scripts/gt-macos.sh`, `gt-linux.sh`, `gt-windows.ps1` | Install, open, upgrade, uninstall test apps and record the UTC time of each |
| `scripts/host-local-check.sh`, `.ps1` | Run every ITAM query on the host with fleetd's osqueryd, with timings |
| `scripts/run-api-tests.sh` | API-only tests (setup, host fields, report cap, export, freshness, uninstall) |
| `scripts/fleet-api.sh` | Fleet API helpers. The token never reaches argv or evidence |
| `scripts/fleet_itam_export.py` | Exporter prototype: Fleet to ServiceNow rows. Dry run unless `--post` |
| `scripts/compare.py` | Ground truth against export, one verdict per check |
| `scripts/tests/` | Unit and smoke tests with a fake Fleet API: `cd scripts && python3 -m unittest discover -s tests` |
| `ground-truth/` | `<host>.tsv`, written by the gt scripts on test day |
| `test-evidence/` | Outputs, one folder per test (created on the first run) |

Status (2026-10-20): Linux sandbox run passed in Ubuntu and Fedora containers (see RESULTS.md and EVIDENCE.md). Lab Fleet, macOS and Windows tests next.

No customer or person names in this folder. Refer to the request by its public issue numbers only.
