---
name: test-issue
description: Point at a GitHub issue and get a test brief to review, then, after approval, have agents run the tests with the repo's framework. Use when the user gives an issue link or number and wants it tested, reproduced, or investigated in the lab ("test this issue", "what do we need for #123", "kick off testing").
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Agent, mcp__Pylon__search_accounts, mcp__Pylon__get_account, mcp__Pylon__search_issues, mcp__Pylon__get_issue, mcp__Pylon__get_issue_messages, mcp__Slack__slack_search_public_and_private, mcp__Slack__slack_read_thread, mcp__Slack__slack_read_channel, mcp__Gong__ask_account, mcp__Gong__ask_deal, mcp__Gong__generate_brief
---

# Test an issue

Issue: $ARGUMENTS

Two phases. Phase 1 changes nothing outside `testing/<project>/`. Phase 2 starts only when the user approves the brief.

Rules for both phases (from `testing/_framework/README.md`): never comment on, react to, or edit anything in
fleetdm/fleet. No customer or person names in committed files: use the customer's GitHub label. Commit messages and PR
text never cite fleetdm/fleet issues.

## Phase 1: research and brief (stop at the end)

Get the full story before planning. Everything that names a customer or a person goes in `testing/<project>/private/`
(git ignored). Read only: don't post, comment, react, or change a ticket anywhere.

1. **The issue.** `testing/_framework/bin/issue.sh <issue>` saves the issue, every comment, the parent issue (when it
   is a sub-issue), and the list of sub-issues. Read all of it. The parent often holds the real ask, so read the parent's
   comments too. Read linked issues and PRs the same way when they change the ask.
2. **Project.** `testing/_framework/bin/new-project.sh <topic>-<issue number> "<title>"`, then move the saved issue into
   its `private/`.
3. **Who the customer is.** Take the `customer-*` label from the issue or its parent. Look it up in fleetdm/confidential:
   the label's description (`gh api repos/fleetdm/confidential/labels/<label>`), then a code search for the label name
   if that is empty. If neither names the customer, ask the user. The real name goes only in `private/CONTEXT.md`.
4. **Customer history,** searched by the real name and by the label:
   - Pylon: the account (`search_accounts`), then its tickets on this topic (`search_issues`, `get_issue_messages`).
   - Slack: `slack_search_public_and_private` for the name, the label, and the issue number. Read the threads in full.
   - Gong: `ask_account` with the questions the issue raises: their setup, versions, what they tried, deadlines.
   If a source isn't connected, say so in the brief and carry on.
5. **Facts.** Check what the issue depends on in Fleet docs and in Fleet code at the customer's release tag. Note
   each source.
6. **`private/CONTEXT.md`:** the full story with names and links, in time order: what they asked, when, what they run,
   what they tried, who is involved, and any deadline. One line per source.
7. **`BRIEF.md`** from `testing/_framework/templates/BRIEF.md`, with no names: the label, versions, and the ask as the
   customer means it. For each test say who runs it:
   - agent now: desk research, code reading, SQL or report logic, Docker Linux, Fleet API reads.
   - overnight queue: VM boots, enrollments, resets, anything over 20 minutes.
   - you: phones, physical Macs, sign-ins with real accounts, anything that posts or changes the lab Fleet.
8. Show the user a short summary in chat: the customer and the full story (from CONTEXT), the ask, the tests, what you
   need from them, and open questions. Give the paths to `BRIEF.md` and `private/CONTEXT.md`. Then stop and wait.
   Don't create fleets, VMs, queues, or agents yet.

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
