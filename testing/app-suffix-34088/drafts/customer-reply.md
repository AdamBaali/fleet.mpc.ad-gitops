<!-- Reply to the customer in their channel, from Adam. Not sent. Attach the five files in sql/ as files, not as Slack snippets, and keep a copy in the support ticket so they do not expire again. -->
Hi, here are the rewritten scripts, tested against Fleet's own schema and ingestion code on 4.90.3 and 4.93.1. You were right about Firefox. A few things changed from February.

**Why the `.app` rows exist**
- **Firefox:** Fleet's `macos_firefox` query names it `Firefox.app` on every Mac with the fleetd tables extension. We reproduced it on 4.93.0. A cleanup of Firefox comes back within the hour, so the scripts leave Firefox alone. We're filing a bug for Fleet to fix the query and merge the existing Firefox rows in a migration. I'll share the issue link.
- **Everything else:** left over from the custom `software_macos` override that was removed in September 2025. These rows clear on their own when a host reports. A host that reports `Slack` loses its `Slack.app` link in the same report, and Fleet deletes the unused row in the vulnerabilities job. What stays is rows on hosts that have been offline since then.
- **Titles:** Fleet never renames an existing title, so `.app` titles stay until renamed.

**What to run**
1. `1_diagnose.sql`. Read only, safe on a replica. Please send us the output. It shows which `.app` rows are still being produced, which are on offline hosts only, and checks our checksum formula against your data. If CHECK 1 shows a `software_macos` override, or CHECK 3 lists anything besides Firefox, stop there and let us know.
2. `4_titles.sql`. Renames `.app` titles, the same as the API script did, for all titles at once. This one fixes the Software titles page for good, Firefox included.
3. Optional: `2_plan.sql`, then `3_apply_batch.sql` repeated until it shows nothing pending, then `5_verify.sql`. This merges or renames the rows on offline hosts. Take a snapshot first. Each run is one transaction and Fleet can keep running. If you'd rather not touch data, those rows clear when the hosts report, or when Fleet removes long-offline hosts.

After step 3, run the vulnerabilities job (or your `fleet vuln_processing` job) so host counts refresh.

The scripts don't change admin display names. CHECK 6 lists any that end in `.app`.

Happy to walk through the diagnose output on a call.
