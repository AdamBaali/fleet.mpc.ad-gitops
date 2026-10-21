<!-- Post for #help-customers, from Adam. Not posted. Tag the on-call engineer for #g-supply-chain. Plain URLs, because Slack doesn't render Markdown links. -->
Review request: SQL cleanup for `.app` software names (`customer-ufa`)

@<on-call engineer> can you review these scripts before they go to the customer this week?

- Problem: self-hosted, upgrading from 4.90.3 to 4.93, plain osquery with `fleetd_tables`. macOS versions show `Firefox.app` next to `Firefox`, plus same-name duplicates.
- Causes: `macos_firefox` hard-codes `Firefox.app` on hosts with `parse_ini` (https://github.com/fleetdm/fleet/blob/fleet-v4.93.1/server/service/osquery_utils/queries.go#L1586-L1628). Bug filed: https://github.com/fleetdm/fleet/issues/56168. https://github.com/fleetdm/fleet/issues/50077 and https://github.com/fleetdm/fleet/issues/50090 don't change it. Other `.app` rows are 2025 override leftovers on offline hosts. The Fleet-maintained app job renamed many of them to catalog names and kept their checksums, so they're now same-name duplicates.
- Scripts: a read-only diagnose, then batched merges of offline-only rows into the row hosts use today, modeled on `mergeDuplicateSoftware` in migration `20260810160000` (https://github.com/fleetdm/fleet/blob/fleet-v4.93.1/server/datastore/mysql/migrations/tables/20260810160000_DedupeSoftwareChecksums.go#L90). Rows with no twin get renamed along with their checksum. Titles with a bundle ID get renamed. Firefox is excluded.
- Tested in Fleet's test database with real ingestion and the Fleet-maintained app job on 4.90.3, 4.93.1, and `main`, and through the `mysql` client. Not run on real data yet.

Please check the merge and rename approach against ingestion, anything that references `software.id` we might miss, and lock time on a large live instance (batches of 100, READ COMMITTED).

Also: https://github.com/fleetdm/fleet/issues/52314 may explain their TeamViewer duplicates and doesn't have `customer-ufa`. Is anyone on it?

Scripts: https://github.com/AdamBaali/fleet.mpc.ad-gitops/tree/main/testing/app-suffix-34088/sql
Test results: https://github.com/AdamBaali/fleet.mpc.ad-gitops/blob/main/testing/app-suffix-34088/RESULTS.md
