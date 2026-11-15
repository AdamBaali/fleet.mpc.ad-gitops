#!/usr/bin/env python3
"""Run a queue of test steps with Claude Code overnight, one fresh session per step.

Usage: overnight.py <queue.md> [--dry-run] [--only ID]

Each step in the queue file:

    ## W-1: Enroll win1 in Fleet
    check: testing/_framework/bin/fleet-api.sh host win1 | grep -q 'status *online'
    timeout: 45m
    model: sonnet            (optional, default $OVERNIGHT_MODEL or sonnet)
    stop_on_fail: yes        (optional: end the run if this step fails)

    What Claude should do, in plain words. Lines up to the next "## " heading.

How it saves usage and stays reliable:
- The check command decides PASS or FAIL, not the model. It runs first too: a step that already passes costs nothing,
  so a stopped run resumes where it left off.
- Each step is a new `claude -p` session, so context doesn't grow all night.
- A failed step gets one retry (OVERNIGHT_RETRIES) with the check output added, unless Claude answered BLOCKED.
  Two failed steps in a row, or a step with stop_on_fail, stop the run.
- A usage limit pauses the run (OVERNIGHT_LIMIT_WAIT minutes, default 30) and tries again, up to 10 times.
- Permissions: dontAsk mode, so anything not allowed in .claude/settings.json is refused, not waited on. Pushes, PRs,
  and GitHub comments are blocked for the run.

Logs and SUMMARY.md go to out/overnight/<queue name>/ (git ignored). On a Mac it keeps the machine awake and posts a
notification at the end. CLAUDE_BIN replaces the claude command, for tests.
"""
import json, os, re, signal, subprocess, sys, threading, time
from datetime import datetime, timezone

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip() or os.getcwd()
HERE = os.path.dirname(os.path.abspath(__file__))
CLAUDE = os.environ.get("CLAUDE_BIN", "claude")
RETRIES = int(os.environ.get("OVERNIGHT_RETRIES", "1"))
MAX_FAILED_IN_ROW = int(os.environ.get("OVERNIGHT_MAX_FAILED", "2"))
LIMIT_WAIT = int(os.environ.get("OVERNIGHT_LIMIT_WAIT", "30")) * 60
# Blocked for every step: the run must never publish anything. The owner reviews in the morning.
DENY = ["Bash(git push *)", "Bash(gh pr *)", "Bash(gh issue *)", "Bash(gh api *)", "mcp__github__*"]

def now(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def seconds(v):
    m = re.fullmatch(r"(\d+)\s*([smh]?)", v.strip())
    if not m: raise SystemExit(f"bad timeout: {v}")
    return int(m.group(1)) * {"": 60, "s": 1, "m": 60, "h": 3600}[m.group(2)]

def parse(path):
    steps, cur = [], None
    for line in open(path):
        h = re.match(r"^##\s+([A-Za-z0-9._-]+):\s*(.+)$", line)
        if h:
            cur = dict(id=h.group(1), title=h.group(2).strip(), check="", timeout="30m", model="",
                       stop_on_fail="no", prompt=[]); steps.append(cur); continue
        if cur is None: continue
        kv = re.match(r"^(check|timeout|model|stop_on_fail):\s*(.+)$", line)
        if kv and not cur["prompt"]: cur[kv.group(1)] = kv.group(2).strip()
        else: cur["prompt"].append(line.rstrip("\n"))
    for s in steps:
        s["prompt"] = "\n".join(s["prompt"]).strip()
        if not s["check"]: raise SystemExit(f"{s['id']}: every step needs a check: line")
    return steps

def check(step, log):
    r = subprocess.run(["bash", "-c", step["check"]], cwd=ROOT, capture_output=True, text=True, timeout=600)
    out = (r.stdout + r.stderr)[-2000:]
    with open(log, "a") as f: f.write(f"\n== check {now()} exit {r.returncode}\n$ {step['check']}\n{out}\n")
    return r.returncode == 0, out

def claude(step, prompt, log, dry):
    cmd = [CLAUDE, "-p", prompt, "--model", step["model"] or os.environ.get("OVERNIGHT_MODEL", "sonnet"),
           "--permission-mode", "dontAsk", "--max-turns", os.environ.get("OVERNIGHT_MAX_TURNS", "60"),
           "--output-format", "stream-json", "--verbose",
           "--append-system-prompt-file", os.path.join(HERE, "overnight-rules.md"),
           "--disallowedTools", *DENY]
    if os.environ.get("OVERNIGHT_EFFORT"): cmd += ["--effort", os.environ["OVERNIGHT_EFFORT"]]
    if dry:
        print("  would run:", " ".join(cmd[:2]), "<prompt>", " ".join(cmd[3:])); return dict(result="dry run")
    result = {}
    with open(log, "a") as f:
        f.write(f"\n== claude {now()}\n")
        p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             start_new_session=True)
        # A watchdog, because a hung session prints nothing and a check between lines would never run.
        fired = threading.Event()
        def kill():
            fired.set()
            try: os.killpg(p.pid, signal.SIGTERM)
            except ProcessLookupError: pass
        timer = threading.Timer(seconds(step["timeout"]), kill); timer.start()
        for line in p.stdout:
            f.write(line); f.flush()
            try: ev = json.loads(line)
            except ValueError: continue
            if ev.get("type") == "result": result = ev
        p.wait(); timer.cancel()
        if fired.is_set():
            result = dict(result="timed out", timed_out=True); f.write(f"\n== timed out after {step['timeout']}\n")
    return result

def limited(result):
    text = json.dumps(result).lower()
    return result.get("is_error") and any(k in text for k in ("usage limit", "rate limit", "limit reached", "overloaded"))

def notify(msg):
    if sys.platform == "darwin":
        subprocess.run(["osascript", "-e", f'display notification "{msg}" with title "Overnight run"'])
    if os.environ.get("NOTIFY_CMD"): subprocess.run(["bash", "-c", os.environ["NOTIFY_CMD"] + ' "$0"', msg])

def main():
    args = sys.argv[1:]
    if not args or args[0].startswith("-"): print(__doc__); return 2
    queue, dry = args[0], "--dry-run" in args
    only = args[args.index("--only") + 1] if "--only" in args else None
    steps = [s for s in parse(queue) if not only or s["id"] == only]
    out = os.path.join(ROOT, "out", "overnight", os.path.splitext(os.path.basename(queue))[0]); os.makedirs(out, exist_ok=True)
    if sys.platform == "darwin" and not dry:
        subprocess.Popen(["caffeinate", "-dims", "-w", str(os.getpid())])
    rows, failed_in_row, stopped = [], 0, ""
    for s in steps:
        log = os.path.join(out, f"{s['id']}.log"); t0 = time.time(); turns = 0; cost = 0.0
        print(f"{now()} {s['id']}: {s['title']}")
        ok, last = check(s, log)
        status, attempts, note = ("PASS", 0, "already passing, no session used") if ok else ("FAIL", 0, "")
        waits = 0
        while not ok and attempts <= RETRIES:
            prompt = f"Step {s['id']}: {s['title']}\n\n{s['prompt']}\n\nThe step passes when this command exits 0:\n{s['check']}"
            if attempts:
                prompt += f"\n\nThe last attempt did not pass. Check output:\n{last}\nLast summary:\n{note}"
            r = claude(s, prompt, log, dry)
            if limited(r) and waits < 10:
                waits += 1; print(f"  usage limit, waiting {LIMIT_WAIT // 60} min"); time.sleep(LIMIT_WAIT); continue
            attempts += 1; turns += r.get("num_turns", 0) or 0; cost += r.get("total_cost_usd", 0) or 0
            note = (r.get("result") or "")[-1500:]
            if dry: status = "DRY-RUN"; break
            ok, last = check(s, log)
            status = "PASS" if ok else ("TIMEOUT" if r.get("timed_out") else "FAIL")
            # Claude said it can't do the step. Another session would spend usage on the same wall.
            if not ok and "BLOCKED:" in note: status = "BLOCKED"; break
        mins = round((time.time() - t0) / 60, 1)
        rows.append((s["id"], s["title"], status, attempts, turns, mins, round(cost, 2), note.splitlines()[-1][:160] if note else ""))
        print(f"  {status} after {attempts} session(s), {mins} min")
        failed_in_row = 0 if status in ("PASS", "DRY-RUN") else failed_in_row + 1
        if status not in ("PASS", "DRY-RUN") and (s["stop_on_fail"] == "yes" or failed_in_row >= MAX_FAILED_IN_ROW):
            stopped = f"stopped after {s['id']}"; break
    with open(os.path.join(out, "SUMMARY.md"), "w") as f:
        f.write(f"# Overnight run: {os.path.basename(queue)}\n\nFinished {now()}. {stopped or 'All steps ran.'}\n\n")
        f.write("| Step | Title | Result | Sessions | Turns | Minutes | Cost estimate USD | Last line |\n|---|---|---|---|---|---|---|---|\n")
        for r in rows: f.write("| " + " | ".join(str(c).replace("|", "/") for c in r) + " |\n")
        f.write("\nLogs: one `<step>.log` per step in this folder. Cost estimate is what the API would charge, not subscription use.\n")
    passed = sum(1 for r in rows if r[2] == "PASS")
    msg = f"{passed}/{len(rows)} steps passed. {stopped}".strip()
    print(msg); print(os.path.join(out, "SUMMARY.md"))
    if not dry: notify(msg)
    return 0 if passed == len(rows) else 1

sys.exit(main())
