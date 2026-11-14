---
name: fleet-test-overnight
description: Write and run an overnight queue of Fleet test steps with Claude Code (one fresh session per step, a script check decides pass or fail, local OCR to drive VM screens without pictures). Use when the user wants tests to run unattended, overnight, in a loop, or while away.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Overnight queue

Task: $ARGUMENTS

Read `testing/_framework/guides/overnight.md`.

1. Split the work into small steps. Each step gets a `check:` command that exits 0 only when the step is truly done
   (a file in test-evidence, a qga answer, a Fleet API field). No check, no step.
2. Write `testing/<project>/QUEUE.md` from `testing/_framework/templates/QUEUE.md`. Put risky steps last, and
   `stop_on_fail: yes` on steps the rest depend on.
3. `testing/_framework/bin/overnight.py <queue> --dry-run`, then `--only <first ID>` with the user watching.
4. Tell the user to start the full run in their own terminal. A run started inside this session ends when it does.
5. In the morning read `out/overnight/<queue>/SUMMARY.md` and the step logs. Report results from the checks, not
   from Claude's summaries.
