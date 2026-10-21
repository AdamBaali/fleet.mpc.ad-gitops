# Handoff: ".app" software name cleanup

## State
- Diagnosis done and verified against Fleet source, the GitHub API and the lab. See README and NOTES.
- `sql/` written and tested: C1 to C5 pass on Fleet 4.90.3, 4.93.1 and `main`. N-1 shows a wrong formula fails safe.
- Not run on customer data. No engineering review yet.
- Nothing posted or sent. Drafts: `drafts/github-issue-firefox-app.md`, `drafts/customer-reply.md`.

## Next steps
1. Engineering review of `sql/` and the bug draft. The customer was told the scripts would be reviewed by engineering.
2. File the bug from `drafts/github-issue-firefox-app.md`. Put its number in TRACKING.md and the customer reply.
3. Send the reply with the five SQL files attached, and store them on the support ticket too. Slack expires attachments.
4. Read the customer's `1_diagnose.sql` output. Expected: recurring rows are Firefox only, CHECK 4 shows 0 mismatches. Anything else changes the plan.
5. After Fleet fixes `macos_firefox`, drop `org.mozilla.firefox` from `@exclude_bundle_ids` if the migration does not merge the old rows.

## Running services
None in the lab. The database tests start Fleet's `mysql_test` container under the compose project `fleet-app-suffix`.

## Teardown
Done 2026-10-21. The `mysql_test` container is stopped and the temporary Fleet worktrees are removed. To run the tests again, check out the Fleet tag you want and run `tests/run-db-tests.sh <checkout>`. No lab Fleet changes were made. L-1 used live queries only.

## Rules learned
- Run SQL meant for a customer against Fleet's real schema and ingestion before sending it. The February SQL had a syntax error.
- A negative control must change something that is not empty for the rows under test.
- Fleet trims `.app` in `software_macos`, but overrides like `macos_firefox` replace whole rows. Check overrides when one app misbehaves.
