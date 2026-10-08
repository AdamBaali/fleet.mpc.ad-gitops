# Testing framework

A small, repeatable way to test Fleet features and guides, and to leave evidence anyone can review without us.
Used first for fleetdm/fleet#54654 (PingFederate and Duo guides). Copy this folder into a new test project.

## What a test project holds
```
<project>/
  TEST_PLAN.md          what we test and why (from templates/TEST_PLAN.md)
  RESULTS.md            running log, one section per test (templates/RESULTS.md)
  EVIDENCE.md           generated: every test, its result, pictures and links to raw output
  NOTES.md              untested items, lab-versus-production caveats, ideas
  HANDOFF.md            where we are, what's running, what to do next (templates/HANDOFF.md)
  ISSUE_UPDATE.md       the short update Adam posts (templates/ISSUE_UPDATE.md). Never auto-posted
  test-evidence/<group>/<ID>-<slug>/   one folder per test: result.md, NN-label.txt, NN-label.png
```

## The loop for every test
1. **Plan:** add the test to `TEST_PLAN.md` with an ID, objective, steps, expected result and a pass/fail rule.
2. **Run it from a script**, so it can be repeated: `ev_init`, then `ev_cmd` (outputs), `ev_shot` (window-only
   pictures), `ev_note`, and finally `ev_verdict ID PASS|FAIL|PARTIAL|NOT-RUN|BLOCKED "one-line reason"`
   (helpers in `bin/ev.sh`).
3. **Record failures before fixing them.** A failure is a finding. Write it down, then fix, then re-run and keep both.
4. **Build the page:** `bin/build-evidence-index.py <project> "<title>" <group>:<Name> ...` writes `EVIDENCE.md`.
5. **Write the update** from `RESULTS.md` in plain language. Adam reviews and posts it.

## Rules
- **Secrets never appear** in outputs, pictures, chat or commits. `ev_cmd` masks values from `SECRETS_ENV`;
  mask pictures with `tools/maskbox.swift` (sign-in codes, tokens, IP addresses, personal data).
- **Window-only screenshots**, never the whole screen (`tools/macterm.sh` for terminal output, `winid` for apps).
- **One result per test** (`## Result: PASS`). The index reads that line. Use INFO for setup notes.
- **Say what was not tested** and what differs from production (`NOTES.md`). Never claim more than the evidence shows.
- **Nothing is pushed or posted automatically.** Prepare commits locally. Adam pushes and posts.
- **Only change the lab Fleet**, and use one fleet per project (declared in the GitOps repo).
- **Check docs and code first**, not memory. Quote the doc or the command you used.
- **Leave it clean:** a teardown list in `HANDOFF.md`, and delete throwaway users, tunnels and services.

## Result words
PASS (expected result observed) · FAIL (not observed) · PARTIAL (works with a caveat, say which) ·
NOT-RUN (planned, not done) · BLOCKED (can't run, say why) · INFO (setup note, not a test).

## One-time setup on a Mac
```bash
swiftc -O -o /usr/local/bin/winid   testing/_framework/tools/winid.swift     # finds a window to capture
swiftc -O -o /usr/local/bin/maskbox testing/_framework/tools/maskbox.swift   # black boxes over pixels
```
