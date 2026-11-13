---
name: fleet-test-project
description: Start, run, and finish a Fleet test project in testing/<project>/ with the repo's framework (plan, scripted tests, evidence, EVIDENCE.md, handoff, drafts). Use this whenever a task is to test a Fleet feature, guide, report, or customer request, reproduce a bug on a lab host, or collect evidence, even if the user never says "framework".
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Fleet test project

Task: $ARGUMENTS

Read `testing/_framework/README.md` for the rules and `testing/_framework/guides/` for host how-tos before you start.
This repository is public: no customer or person names in committed files, no secrets, and no fleetdm/fleet issue
references in commit messages or PR text.

## Start

1. Read the issue in full with its comments. Read the code at the release tag the customer runs, not only `main`.
2. `testing/_framework/bin/new-project.sh <topic>-<issue number> "<title>"` creates `testing/<project>/` from the templates.
3. Put the customer name, Slack, ticket, and call links only in `testing/<project>/private/` (git ignores it).
4. If the test needs a fleet, add `fleets/<name>.yml` with the `fleet-gitops` skill, through a pull request. A push to
   `main` applies to the lab Fleet.
5. Write `TEST_PLAN.md`: for each test an ID, steps, expected result, and a pass rule that someone can observe.
6. Create `private/fleet.env` (`FLEET_URL`, `FLEET_API_TOKEN`). See `guides/fleet-and-packages.md`.

## Run

1. Check the clock: `testing/_framework/bin/clock-check.sh`.
2. Pick the host guide: `guides/windows-hosts.md`, `linux-hosts.md`, `macos-hosts.md`, or `phones-and-video.md`.
3. Script every test so it can be repeated. Source `bin/ev.sh` with `EV` and `SECRETS_ENV` set, then
   `ev_init`, `ev_cmd`, `ev_shot`, `ev_note`, `ev_verdict ID PASS|FAIL|PARTIAL|NOT-RUN|BLOCKED "reason"`.
4. First test is the host facts: `hosts/host-facts.sh` (Linux, macOS) or `hosts/host-facts.ps1` (Windows).
5. Record a failure before fixing it. Keep both runs.
6. Anything a customer will run: run it at the customer's versions, the way they will run it, add a negative control
   that changes something that matters, and get an independent review.

## Finish

1. `testing/_framework/bin/build-evidence-index.py testing/<project> "<title>" <group>:<Name> ...` writes `EVIDENCE.md`.
2. Fill `RESULTS.md`, `NOTES.md` (what was not tested, lab versus production), and `README.md`.
3. Write `HANDOFF.md` with a teardown list: throwaway users, enroll secrets, tokens, VMs, tunnels, containers.
4. Drafts for the owner to post go in `testing/<project>/drafts/`. Never post them. Never claim more than the evidence shows.
5. Update the project table in the root `README.md`.
6. Work on a branch and open a pull request only when asked.
