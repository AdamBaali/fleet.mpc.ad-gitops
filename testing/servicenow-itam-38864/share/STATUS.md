# Status: software inventory to ServiceNow ITAM (#38864)

Internal summary, 2026-10-19. No customer or person names. Refer to the request by issue number.

## What the customer asked for
From the help-customers request (2026-10-19) and the #38864 call notes (2026-10-06):

| Ask | Detail |
|---|---|
| Installed software on each host in ServiceNow | Main gap. Most hardware is already there |
| macOS | Required. Their ServiceNow setup shows only Windows today |
| First installed and last run per app | For each app on each host |
| Near real time | Hourly sync |
| Timeline | NYDFS audit in March. They have their own SOC audit deadlines and asked for something by the end of the year |

The customer said they would rather build their own stopgap than buy and deploy a tool they remove a few months later. They asked whether the built-in connector (#38864) can move to this year.

## Where the built-in work stands
| Issue | What | State | Progress |
|---|---|---|---|
| #38864 | Connect Fleet to ServiceNow ITAM | Open, P2, milestone 5.1.0 | Unassigned, no PRs. Only "first draft of test plan" is checked. 5.1.0 targets Dec 25, and engineering said a January release is more likely. No date commitment |
| #54912 | Install date (or first seen) per software item | Open, P2, 5.1.0, child of #16634 | Unassigned, no PRs. No choice yet between OS install date, first seen, or both |
| #54914 | Publisher per software item | Open, P2, 5.1.0, child of #37087 | Unassigned, no PRs. No choice yet for the macOS source |
| #37087 | Publisher in the software view and exports (original request) | Open, no milestone | Tracked through #54914 |
| #16634 | Install date in the osquery `apps` table | Open, no milestone | Tracked through #54912. Upstream osquery/osquery#6422 has no PR |
| #15693 | Customize the report cap in the UI | Open | `report_cap` is settable in GitOps today |

The agreed plan (g-orchestration, 2026-10-19): the customer solutions architect team builds a stopgap exporter, so engineering stays on 5.1.0. The customer moves to the built-in connector when it ships. A confidential tracking issue holds the customer details. It is not quoted here.

## What the stopgap is
Reports only, nothing installed on hosts. An osquery extension was built and tested, then dropped on 2026-10-20 to keep the stopgap simple. Linux report SQL ran in Ubuntu and Fedora containers on 2026-10-20 (`RESULTS.md`). Lab hosts next (`TEST_PLAN.md`).

| Part | Where | State |
|---|---|---|
| Native reports for install date and publisher (macOS, Windows, Linux) | `lib/*/reports/software-itam.reports.yml` | Linux SQL ran in osquery. macOS and Windows checked against the schema |
| Exporter prototype to ServiceNow Import Set, with its own first seen date per app | `scripts/fleet_itam_export.py` | Python tests pass against a fake Fleet API |
| Tests covering every field in #38864 | `TEST_PLAN.md`, `scripts/` | Linux sandbox done. Lab hosts next |

What the customer gets per field, today with the stopgap:

| Field | macOS | Windows | Linux |
|---|---|---|---|
| Name, version, install path | Built in | Built in | Built in (no path) |
| Last run | Built in (`last_opened_at`) | Built in, from Prefetch, for programs with an install location | Built in, from file access times. DEB needs osquery 5.19 or later |
| Publisher | Report: code signing certificate name | Report: registry publisher (Fleet stores it but the API doesn't return it) | Report: RPM vendor, DEB maintainer |
| Install date | Report: Spotlight date added, bundle created. Tests pick one | Report: registry InstallDate, else Uninstall key write time | Report: RPM install time of the version on disk. DEB: last changed. Both move on upgrade and reinstall (sandbox run) |
| First seen | Exporter, from its first run | Exporter, from its first run | Exporter, from its first run. The only date that stays put on Linux |

## Gaps and where each is filed
| Gap | Filed | Action |
|---|---|---|
| No install date in Fleet | #54912 | Add the per-OS sources we tested (see `FEATURE_REQUEST.md`, evidence comments) |
| No publisher on macOS, not returned on Windows and Linux | #54914 | Same. Native `signature.authority` already gives the macOS name, no fleetd change needed |
| No ServiceNow connector | #38864 | None |
| Stored report results are capped per report, so a report with one row per app clips at fleet scale | Not filed | New feature request, drafted in `FEATURE_REQUEST.md` |

## Recommendation
1. Run the tests on 2026-10-20 before telling the customer which dates are reliable. Present every date with its source, so the audit sees a proxy as a proxy.
2. Offer the reports and the exporter. They need nothing installed and go away with a YAML delete when #54912 and #54914 ship. Label Linux install dates honestly: DEB is last changed, RPM is the latest install. Send `first_seen` with every row so auditors have a fixed date.
3. Publish `export-software-inventory-to-servicenow.md` as a Fleet guide after the tests pass, so other customers can use the same stopgap. Contribute the exporter to `docs/solutions/api-scripts/` with it.
4. File the report cap feature request, and post the evidence comments on #54912 and #54914.
