# Testing framework

Test a Fleet feature or guide, and leave evidence anyone can review: commands, their output, and window screenshots.


## Rules

- This repository is public. No customer or person names, no secrets, no serial numbers in committed files. Use the
  customer's GitHub label. Internal links and names go in `testing/<project>/private/`, which git ignores.
- Never comment on, edit, or open anything in fleetdm/fleet. Write the text as a draft in `drafts/` and the owner posts it.
- PR titles, PR descriptions, and commit messages never cite fleetdm/fleet issues: each mention leaves a permanent link on
  the issue. Files may cite issues.
- Work on a branch and open a pull request. A push to `main` applies to the lab Fleet.
- Check facts in docs and code at the customer's release tag. Don't claim more than the evidence shows.
- Anything a customer will run: test it at their versions, the way they will run it, with a negative control.
- Leave the lab clean: list what to delete in `HANDOFF.md`.


## Start a test

```bash
testing/_framework/bin/new-project.sh <topic>-<issue number> "<title>"   # copies the templates
export EV=$PWD/testing/<project>/test-evidence/<group> SECRETS_ENV=$PWD/testing/<project>/private/fleet.env
. testing/_framework/bin/ev.sh
```

Then write `TEST_PLAN.md` and pick a host guide:
[Windows](guides/windows-hosts.md) · [Linux](guides/linux-hosts.md) · [macOS](guides/macos-hosts.md) ·
[phones and video](guides/phones-and-video.md) · [Fleet and packages](guides/fleet-and-packages.md) ·
[overnight runs](guides/overnight.md).


## Record evidence

```bash
ev_init T-1 "name" "objective" "expected"      # makes <ID>-<slug>/result.md
ev_cmd  T-1 label "command"                    # runs it, saves the masked output as NN-label.txt
ev_shot T-1 label "Google Chrome"              # window-only screenshot (macOS)
ev_verdict T-1 PASS|FAIL|PARTIAL|NOT-RUN|BLOCKED "one line"
bin/build-evidence-index.py testing/<project> "<title>" <group>:<Name>    # writes EVIDENCE.md
```

Record a failure before fixing it. Keep both runs. One `## Result:` line per test.


## What is here

| Path | What |
|---|---|
| `bin/` | `ev.sh`, `build-evidence-index.py`, `new-project.sh`, `fleet-api.sh` (read-only), `clock-check.sh`, `status.sh`, `redact.py`, `overnight.py` |
| `hosts/host-facts.sh`, `host-facts.ps1` | Run on a host: OS, fleetd, time. The first evidence item |
| `tools/phone-cam.sh` | Record a phone screen with a UTC clock and a live view |
| `tools/macterm.sh`, `winid.swift`, `maskbox.swift` | Window-only screenshots and masking (macOS) |
| `vm/` | QEMU tools for Windows VMs ([vm/README.md](vm/README.md)). `screen.sh` and `ocr.py` read, wait on, and click screen text locally |
| `claude/settings.example.json` | Allow rules for unattended runs. Copy what you need into `.claude/settings.local.json` |
| `guides/` | One page per host type |
| `templates/` | README, TEST_PLAN, RESULTS, NOTES, STATUS, HANDOFF, ISSUE_UPDATE |

Skills in `.claude/skills/`: `fleet-test-project` (start here), `fleet-test-windows-host`, `fleet-test-linux-host`,
`fleet-test-macos-host`, `fleet-test-phone-video`, `fleet-test-overnight`, `fleet-gitops`.

One-time setup on a Mac:
```bash
swiftc -O -o /usr/local/bin/winid   testing/_framework/tools/winid.swift
swiftc -O -o /usr/local/bin/maskbox testing/_framework/tools/maskbox.swift
brew install ffmpeg qemu swtpm tesseract
python3 -m pip install --user pillow
```
