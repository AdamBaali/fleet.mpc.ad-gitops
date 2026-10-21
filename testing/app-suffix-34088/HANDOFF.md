# Handoff: ".app" software name cleanup


## State

- Diagnosis done and verified against Fleet source, the GitHub API, and the lab. See README and NOTES.
- `sql/` written and tested: C1 to C8 and the client smoke test (CL-1) pass on Fleet 4.90.3, 4.93.1, and `main`. N-1 shows a wrong formula fails safe.
- An independent review of the SQL ran it at 202,000 software rows with `EXPLAIN` and lock tests. Its findings are fixed and covered by C6 to C8 and CL-1.
- Not run on customer data.
- Done 2026-10-21:
  - The update went to the customer thread.
  - The Firefox bug was filed as [fleetdm/fleet#56168](https://github.com/fleetdm/fleet/issues/56168).
  - The review request was posted in #help-customers, with the scripts attached.
- Waiting on the on-call engineer's review and the customer's 4.93 upgrade.


## Next steps

1. Fold the on-call review into `sql/`, then rerun `tests/run-db-tests.sh` and `tests/run-client-smoke.sh` on 4.93.1 at least.
2. After the review, send `drafts/customer-reply.md` in the customer thread with the five SQL files attached. Store the files on the support ticket too, because Slack expires attachments.
3. Once they've upgraded to 4.93, ask them to run `1_diagnose.sql` and send the output. Expected: recurring rows are Firefox only, and CHECK 4 shows 0 unexplained. Anything else changes the plan.
4. Use their CHECK 7 numbers to decide whether to raise #52314 with the product team. No comment is planned on it otherwise.
5. Follow #56168. After Fleet fixes `macos_firefox`, drop `org.mozilla.firefox` from `@exclude_bundle_ids` if the fix's migration doesn't merge the old rows.


## Running services

None in the lab. The database tests start Fleet's `mysql_test` container under the compose project `fleet-app-suffix`.


## Teardown

Done 2026-10-21. The `mysql_test` container is stopped and the temporary Fleet worktrees are removed. To run the tests again, check out the Fleet tag you want and run `tests/run-db-tests.sh <checkout>`. No lab Fleet changes were made. L-1 used live queries only.


## Rules learned

- Run SQL meant for a customer against Fleet's real schema and ingestion before sending it. `tests/run-db-tests.sh` does that.
- A negative control must change something that is not empty for the rows under test.
- Fleet trims `.app` in `software_macos`, but overrides like `macos_firefox` replace whole rows. Check overrides when one app misbehaves.
