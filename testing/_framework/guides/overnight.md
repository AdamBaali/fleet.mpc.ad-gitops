# Overnight runs

Run a queue of steps with Claude Code while you sleep, and read `SUMMARY.md` in the morning.

```bash
testing/_framework/bin/overnight.py testing/<project>/QUEUE.md --dry-run   # parse, check, show the commands
testing/_framework/bin/overnight.py testing/<project>/QUEUE.md             # run (in a terminal you leave open)
```

Write the queue from `templates/QUEUE.md`. Each step has a title, a `check:` command, a `timeout:`, and plain
instructions. The check decides PASS, not Claude.

## How it saves usage
- The check runs first. A step that already passes costs nothing, so rerunning a stopped queue resumes it.
- Each step is a new `claude -p` session (Sonnet by default, `OVERNIGHT_MODEL=opus` or `model:` per step). Context
  doesn't grow all night.
- One retry with the check output. A step that answers `BLOCKED:` gets none. Two failures in a row end the run.
- Screens are read with local OCR (`vm/screen.sh text|wait|find|click`), so waiting costs no tokens. A picture
  (`screen.sh look`, 1024 wide) only when text isn't enough, capped at 10 a step by the rules.
- A usage limit pauses the run for 30 minutes and tries again.

## Before the first night
1. Run one step at your desk with `--only <ID>`. Watch `out/overnight/<queue>/<ID>.log`.
2. Permissions: the run uses `dontAsk`, so anything not allowed is refused, not waited on. Copy the allow rules from
   [../claude/settings.example.json](../claude/settings.example.json) into `.claude/settings.local.json` (personal) or
   `.claude/settings.json` (shared), and trim them to what your steps need. Pushes, PRs, and GitHub comments are always
   blocked for the run.
3. Install `tesseract` and Pillow for `screen.sh`: `brew install tesseract; python3 -m pip install --user pillow`.
4. Leave the Mac on power. The runner keeps it awake (`caffeinate`) and posts a notification at the end.
   `NOTIFY_CMD` runs any other command with the summary line.

## Driving a Windows screen
| Need | Command | Model cost |
|---|---|---|
| Wait for a screen | `vm/screen.sh <vm> wait 'region' 900` | none |
| Wait until it settles | `vm/screen.sh <vm> still 30` | none |
| Read it | `vm/screen.sh <vm> text` | a few lines of text |
| Click a button | `vm/screen.sh <vm> click 'Next'` | none |
| Type | `vm/qmp.sh <vm> type 'text'`, `keys ret` | none |
| Anything inside Windows | `vm/qga.sh <vm> '<powershell>'` | output text |
| See it | `vm/screen.sh <vm> look out.png` | one picture |

OCR was checked on lab screenshots from Windows setup. It reads small grey placeholder text poorly. Use `qga.sh` for
console output.

## What else is out there
- Claude Code's own computer use (macOS, `/mcp`) controls Mac apps and doesn't work with `claude -p`, so it can't run a
  queue. `screen.sh` drives the VM headless instead.
- Windows-MCP (CursorTouch) reads Windows UI Automation from inside the guest. It needs Python 3.14 in the VM, and arm64
  is untested. Worth a try for apps with many controls.
- The Ralph loop (one prompt, fresh context, repeat) inspired the one-session-per-step design. Its known failure is
  false completion, which the `check:` line prevents.
