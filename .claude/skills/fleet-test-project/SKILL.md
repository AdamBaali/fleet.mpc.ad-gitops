---
name: fleet-test-project
description: Start and run a Fleet test project in testing/<project>/ with the repo's framework. Use whenever the task is to test a Fleet feature, guide, report, or customer request, reproduce a bug on a lab host, or collect evidence, even if the user never says "framework".
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Fleet test project

Task: $ARGUMENTS

Read `testing/_framework/README.md` (rules and commands) first.

1. Read the issue in full with comments, and the code at the customer's release tag.
2. `testing/_framework/bin/new-project.sh <topic>-<issue number> "<title>"`. Names, Slack, and ticket links go only in `private/`.
3. Write `TEST_PLAN.md`: for each test an ID, steps, expected result, and an observable pass rule.
4. Pick the host guide in `testing/_framework/guides/`, or the skill: `fleet-test-windows-host`, `fleet-test-linux-host`, `fleet-test-macos-host`, `fleet-test-phone-video`. A fleet change goes through `fleet-gitops` and a pull request.
5. Run each test from a script with `bin/ev.sh`. First test: host facts. Record failures before fixing them.
6. `bin/build-evidence-index.py` writes `EVIDENCE.md`. Fill `RESULTS.md`, `NOTES.md`, and `HANDOFF.md` (teardown list).
7. Anything for fleetdm/fleet goes in `drafts/` for the owner to post. Never post, comment, or link issues in commits or PRs.
