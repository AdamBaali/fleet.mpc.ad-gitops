# Handoff: ".app" software name cleanup


## State

- Diagnosis done and verified against Fleet source, the GitHub API, and the lab. See README and NOTES.
- `sql/` written and tested: C1 to C4 pass on Fleet 4.90.3, 4.93.1, and `main`. N-1 shows a wrong formula fails safe.
- Not run on customer data. No engineering review yet.
- Nothing posted or sent. Drafts: `drafts/help-customers-post.md`, `drafts/github-issue-firefox-app.md`, `drafts/issue-comment-52314.md`, `drafts/customer-reply.md`.


## Next steps

1. Send `drafts/customer-update-now.md` in the customer thread.
2. Post `drafts/help-customers-post.md` in #help-customers and tag the on-call engineer. Fold their review into `sql/` and rerun `tests/run-db-tests.sh`.
3. File the bug from `drafts/github-issue-firefox-app.md`. Put its number in TRACKING.md and the customer reply.
4. Add `customer-ufa` to #52314 and post `drafts/issue-comment-52314.md`. Add the customer's CHECK 7 numbers when they arrive.
5. After the review, send the customer reply with the five SQL files attached, and store them on the support ticket too. Slack expires attachments.
6. Read the customer's `1_diagnose.sql` output. Expected: recurring rows are Firefox only, CHECK 4 shows 0 unexplained. Anything else changes the plan.
7. After Fleet fixes `macos_firefox`, drop `org.mozilla.firefox` from `@exclude_bundle_ids` if the migration does not merge the old rows.


## Running services

None in the lab. The database tests start Fleet's `mysql_test` container under the compose project `fleet-app-suffix`.


## Teardown

Done 2026-10-21. The `mysql_test` container is stopped and the temporary Fleet worktrees are removed. To run the tests again, check out the Fleet tag you want and run `tests/run-db-tests.sh <checkout>`. No lab Fleet changes were made. L-1 used live queries only.


## Rules learned

- Run SQL meant for a customer against Fleet's real schema and ingestion before sending it. `tests/run-db-tests.sh` does that.
- A negative control must change something that is not empty for the rows under test.
- Fleet trims `.app` in `software_macos`, but overrides like `macos_firefox` replace whole rows. Check overrides when one app misbehaves.
