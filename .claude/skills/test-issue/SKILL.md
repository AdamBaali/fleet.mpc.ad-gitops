---
name: test-issue
description: Point at a GitHub issue and get a test brief to review, then, after approval, have agents run the tests with the repo's framework. Use when the user gives an issue link or number and wants it tested, reproduced, or investigated in the lab ("test this issue", "what do we need for #123", "kick off testing").
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Agent
---

# Test an issue

Issue: $ARGUMENTS

Two phases. Phase 1 changes nothing outside `testing/<project>/`. Phase 2 starts only when the user approves the brief.

Rules for both phases (from `testing/_framework/README.md`): never comment on, react to, or edit anything in
fleetdm/fleet. No customer or person names in committed files: use the customer's GitHub label. Commit messages and PR
text never cite fleetdm/fleet issues.

## Phase 1: brief (stop at the end)

1. `testing/_framework/bin/issue.sh <issue>` from inside the new project, or to stdout first to pick the slug. Read it all,
   with every comment. Read linked issues and PRs the same way when they change the ask.
2. `testing/_framework/bin/new-project.sh <topic>-<issue number> "<title>"`, then save the issue to its `private/`.
3. Check what the issue depends on in docs and in Fleet code at the customer's release tag. Note sources.
4. Write `testing/<project>/BRIEF.md` from `testing/_framework/templates/BRIEF.md`. For each test say who runs it:
   - agent now: desk research, code reading, SQL or report logic, Docker Linux, Fleet API reads.
   - overnight queue: VM boots, enrollments, resets, anything over 20 minutes.
   - you: phones, physical Macs, sign-ins with real accounts, anything that posts or changes the lab Fleet.
5. Show the user a short summary in chat (the ask, the tests, what you need from them, the questions) and the path to
   `BRIEF.md`. Then stop and wait. Don't create fleets, VMs, queues, or agents yet.

## Phase 2: run (after approval, with the user's edits)

1. Turn the brief into `TEST_PLAN.md`. If the lab needs a fleet, write `fleets/<name>.yml` with the `fleet-gitops` skill
   on a branch and ask the user to merge the PR.
2. "Agent now" tests: start one Agent per independent test, in one message, at most 3, `model: sonnet`. Brief each with
   the test ID, the project path, the pass rule, and the rule to record evidence with `testing/_framework/bin/ev.sh` in
   `test-evidence/<group>/`. Tell each to stop and report BLOCKED rather than guess.
3. Overnight tests: write `QUEUE.md` (the `fleet-test-overnight` skill), run `--dry-run`, and give the user the one command
   to start it in their terminal.
4. "You" tests: write a checklist in `HANDOFF.md` with the exact steps and what to send back.
5. When results are in: `build-evidence-index.py`, fill `RESULTS.md` and `NOTES.md`, and draft the issue update in
   `drafts/ISSUE_UPDATE.md` for the user to post. Report PASS or FAIL from the evidence, not from agent summaries.
