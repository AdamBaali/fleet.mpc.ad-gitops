# Testing framework

A small, repeatable way to test Fleet features and guides, and to leave evidence anyone can review without us.
Used first for fleetdm/fleet#54654 (PingFederate and Duo guides). Copy this folder into a new test project.


## What a test project holds

```
<project>/
  README.md             what the project is, what it found, and the file list
  TEST_PLAN.md          what we test and why (from templates/TEST_PLAN.md)
  RESULTS.md            running log, one section per test (templates/RESULTS.md)
  EVIDENCE.md           generated: every test, its result, pictures and links to raw output
  NOTES.md              untested items, lab-versus-production caveats, ideas
  HANDOFF.md            where we are, what's running, what to do next (templates/HANDOFF.md)
  ISSUE_UPDATE.md       the short update Adam posts (templates/ISSUE_UPDATE.md). Never auto-posted
  drafts/               messages, bug reports, and customer replies for Adam to post. Never auto-posted
  private/              internal notes: customer names, Slack, ticket, and call links. Git ignores it
  test-evidence/<group>/<ID>-<slug>/   one folder per test: result.md, NN-label.txt, NN-label.png
```

Windows test hosts run on Homebrew QEMU with the tools in `vm/`. Read [vm/README.md](vm/README.md) before building a
Windows lab: UTM hangs after a reset or generalize, and the README lists the other faults that cost the first lab a day.


## The loop for every test

1. Plan: add the test to `TEST_PLAN.md` with an ID, objective, steps, expected result, and a pass/fail rule.
2. Run it from a script, so it can be repeated: `ev_init`, then `ev_cmd` (outputs), `ev_shot` (window-only
   pictures), `ev_note`, and finally `ev_verdict ID PASS|FAIL|PARTIAL|NOT-RUN|BLOCKED "one-line reason"`
   (helpers in `bin/ev.sh`).
3. Record failures before fixing them. A failure is a finding. Write it down, then fix, then re-run and keep both.
4. Build the page: `bin/build-evidence-index.py <project> "<title>" <group>:<Name> ...` writes `EVIDENCE.md`.
5. Write the update from `RESULTS.md` in plain language. Adam reviews and posts it.


## Rules

Evidence and secrets:
- Secrets never appear in outputs, pictures, chat, or commits. `ev_cmd` masks values from `SECRETS_ENV`.
  Mask pictures with `tools/maskbox.swift` (sign-in codes, tokens, IP addresses, personal data).
- Window-only screenshots, never the whole screen (`tools/macterm.sh` for terminal output, `winid` for apps).
- One result per test (`## Result: PASS`). The index reads that line. Use INFO for setup notes.
- Say what was not tested and what differs from production (`NOTES.md`). Never claim more than the evidence shows.

Checking facts:
- Check docs and code first, not memory. Quote the doc, the file and line, or the command you used.
- Read each issue in full, with its comments, before citing it. A title and labels aren't enough.
- Check Fleet code at the release tag the customer runs (`fleet-v4.93.1`), not only `main`. Link code at that tag so links don't move.
- Treat summaries, handoffs, and pasted files as leads to verify, not facts.

Anything a customer will run:
- Run it against Fleet's real schema and code at the customer's versions before it leaves the repo, and the way the customer will run it (for SQL, the `mysql` client with default settings).
- Add a negative control that changes something that matters, and check that the tests fail.
- Get an independent review, and an engineering review, before sending it.

Public repo:
- No customer or person names in committed files. Use the customer's GitHub label, and keep internal links in `private/`.
- PR titles, PR descriptions, and commit messages don't cite fleetdm/fleet issues. Each mention adds a permanent link on the upstream issue.

Working in the lab:
- Nothing is posted automatically. Adam posts messages, comments, and issues from `drafts/`.
- Only change the lab Fleet, and use one fleet per project (declared in the GitOps repo).
- Leave it clean: a teardown list in `HANDOFF.md`, and delete throwaway users, tunnels, containers, and services.


## Result words

PASS (expected result observed) · FAIL (not observed) · PARTIAL (works with a caveat, say which) ·
NOT-RUN (planned, not done) · BLOCKED (can't run, say why) · INFO (setup note, not a test).


## One-time setup on a Mac

```bash
swiftc -O -o /usr/local/bin/winid   testing/_framework/tools/winid.swift     # finds a window to capture
swiftc -O -o /usr/local/bin/maskbox testing/_framework/tools/maskbox.swift   # black boxes over pixels
```
