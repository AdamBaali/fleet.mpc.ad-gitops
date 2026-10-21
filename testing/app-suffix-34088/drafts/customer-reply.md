<!-- Reply to the customer in their channel, from Adam. Not sent. Send after engineering review. Attach the five files in sql/ as files, not as Slack snippets, and keep a copy in the support ticket so they do not expire. Fill in the two issue numbers. -->
Hi, here are the updated scripts, tested against Fleet's own schema and ingestion code on 4.90.3 and 4.93.1. You were right about Firefox.

**Why the `.app` rows exist**
- **Firefox:** Fleet's `macos_firefox` query names it `Firefox.app` on every Mac with the fleetd tables extension. We reproduced it on 4.93.0. A cleanup of Firefox comes back within the hour, so the scripts leave Firefox rows alone. We filed #____ for Fleet to fix the query and merge the existing Firefox rows in a migration.
- **Everything else:** left over from the custom `software_macos` override removed in September 2025. These rows clear on their own when a host reports. A host that reports `Slack` loses its `Slack.app` link in the same report, and Fleet deletes the unused row in the vulnerabilities job. What stays is rows on hosts that have been offline since then.
- **Titles:** Fleet never renames an existing title, so `.app` titles stay until renamed.

**Related: duplicate versions (TeamViewer and others)**
Rows created before Fleet 4.76.0 kept an older checksum, so a host reporting the same software can create a second row with split host counts. That is #52314, and we've added you to it. Fleet's 4.91.0 migration repairs giflib only, so your 4.93 upgrade fixes giflib with no manual steps. CHECK 7 in `1_diagnose.sql` counts what's left, by source.

**What to run**
1. `1_diagnose.sql`. Read only, safe on a replica. Please send us the output. Stop there and let us know if CHECK 1 shows a `software_macos` override, CHECK 3 lists anything besides Firefox, or CHECK 4 shows `unexplained` above 0.
2. `4_titles.sql`. Renames `.app` titles, the same as the API script did, for all titles at once. This fixes the Software titles page for good, Firefox included.
3. Optional: `2_plan.sql`, then `3_apply_batch.sql` repeated until it shows nothing pending, then `5_verify.sql`. This merges or renames the `.app` rows on offline hosts. `2_plan.sql` shows every change before anything is touched. Take a snapshot first. Each run is one transaction and Fleet can keep running. If you'd rather not touch data, those rows clear when the hosts report, or when Fleet removes long-offline hosts.

After step 3, run the vulnerabilities job (or your `fleet vuln_processing` job) so host counts refresh.

The scripts don't change admin display names. CHECK 6 lists any that end in `.app`.

Happy to walk through the diagnose output on a call, or at the Nov 4 visit.
