<!-- Reply to the customer in their channel, from Adam. Not sent. Send after the engineering review. Attach the five files in sql/ as files, not as Slack snippets, and keep a copy in the support ticket so they don't expire. -->
Hi, here are the updated scripts. Our engineers reviewed them, and we ran them against Fleet 4.90.3 and 4.93.1 in a test database. They haven't run on a production instance yet, so please start with the read-only script. You were right about Firefox. Also, https://github.com/fleetdm/fleet/issues/50077 and https://github.com/fleetdm/fleet/issues/50090, which we linked on the 12th, don't change the macOS Firefox name. #50090 fixes Firefox 153.0 CVE false positives in 4.94.0.

Why the `.app` rows exist:
- Firefox: Fleet's `macos_firefox` query names it `Firefox.app` on every Mac with the `fleetd_tables` extension. We reproduced it on 4.93.0. A cleanup of Firefox would come back on the next software report, so the scripts leave Firefox rows alone. We filed https://github.com/fleetdm/fleet/issues/56168 for Fleet to fix the query and merge the existing Firefox rows in a migration.
- Other apps: these rows are left over from the custom `software_macos` override you removed in September 2025. They clear when a host reports. For example, a host that reports `Slack` loses its `Slack.app` link in the same report, and Fleet deletes the unused row in the vulnerabilities job. Only rows on hosts that have been offline since then stay.
- Apps in Fleet's catalog: the hourly Fleet-maintained app job renames old `.app` rows to the catalog name, for example `Zoom.app` to `Zoom`. That leaves a second `Zoom` row for the same version. The scripts merge these too.
- Titles: software ingestion never renames an existing title, so `.app` titles stay until someone renames them. The Fleet-maintained app job renames titles of catalog apps, but not Firefox.

Duplicate versions (TeamViewer and others): rows created before Fleet 4.75.0 kept an older checksum, so a host that reports the same software can create a second row with split host counts. That's https://github.com/fleetdm/fleet/issues/52314, and it may explain the TeamViewer duplicates. CHECK 7 in `1_diagnose.sql` counts these rows by source, which will tell us. Fleet's 4.91.0 migration repairs giflib only, and your 4.93 upgrade runs it as part of the normal database migration.

What to run, after the 4.93 upgrade. Run each script with the `mysql` command-line client (`mysql ... fleet < 1_diagnose.sql`), not a GUI, and never with `--force`. The scripts that change data set READ COMMITTED so they don't block Fleet's ingestion, which needs `binlog_format` ROW or MIXED, or the binary log off:
1. Run `1_diagnose.sql`. It's read-only and safe on a replica. Please send us the output. Stop and let us know if CHECK 1 shows a `software_macos` override, CHECK 3 lists anything besides Firefox, or CHECK 4 shows `unexplained` above 0.
2. Run `4_titles.sql`. It renames `.app` titles in bulk, like the API script did. Ingestion won't rename them back, so this holds for Firefox too.
3. Optionally, run `2_plan.sql`, then `3_apply_batch.sql` until it shows nothing pending, then `5_verify.sql`. These merge or rename the `.app` rows and the same-name duplicates on offline hosts. `2_plan.sql` lists every change before anything is touched. Take a snapshot first. Each run is one transaction, and Fleet can keep running. If you'd rather not change data, these rows clear when the hosts report, or when long-offline hosts are removed.

After step 3, run the vulnerabilities job (or your `fleet vuln_processing` job) so host counts refresh.

The scripts don't change admin display names. CHECK 6 lists any that end in `.app`.

Happy to walk through the diagnose output on a call, or at the visit on November 4.
