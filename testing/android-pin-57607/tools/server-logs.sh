#!/usr/bin/env bash
# Fleet server logs from Render for a test run's time window, cut to the lines about Android enrollment and profiles.
# The Android enrollment and policy messages are debug level in Fleet, so they appear only with FLEET_LOGGING_DEBUG=true
# on the Render service.
#
# Usage: server-logs.sh SINCE [UNTIL]          UTC times, for example 2026-11-05T09:30:00Z. UNTIL defaults to now.
# Needs the Render CLI logged in (render login) and RENDER_SERVICE_ID (the srv-... ID of the Fleet service).
#
# This repo is public, so the output masks the token in Google's Pub/Sub push URL
# (/api/v1/fleet/android_enterprise/pubsub?token=...): it authenticates Google's calls to the live Fleet. IP addresses
# and the lab admin's email stay: the lab tenant and test phone are throwaway (owner's call, 2026-11-05).
set -euo pipefail
since="${1:?usage: server-logs.sh SINCE [UNTIL]}"; until="${2:-$(date -u +%FT%TZ)}"
: "${RENDER_SERVICE_ID:?set RENDER_SERVICE_ID in private/fleet.env}"

# Render returns at most 1000 lines per call, and debug logging writes about 250 a minute, so page forward from the
# last timestamp until the window is covered.
start="$since"; pages=0
while :; do
  page=$(render logs --resources "$RENDER_SERVICE_ID" --start "$start" --end "$until" --direction forward \
    --limit 1000 --output json --confirm)
  pages=$((pages + 1))
  printf '%s\n' "$page"
  last=$(printf '%s' "$page" | python3 -I -c '
import json, sys
raw = sys.stdin.read(); dec = json.JSONDecoder(); pos = 0; n = 0; last = ""
while True:
    while pos < len(raw) and raw[pos].isspace():
        pos += 1
    if pos >= len(raw):
        break
    o, pos = dec.raw_decode(raw, pos); n += 1; last = o.get("timestamp", last)
print(n, last)')
  n=${last%% *}; ts=${last#* }
  # A short page means the window is done. The 50-page stop guards against a loop if Render repeats a page.
  [ "$n" -lt 1000 ] || [ -z "$ts" ] || [ "$pages" -ge 50 ] && break
  start="$ts"
done | python3 -I -c '
import json, re, sys
raw = sys.stdin.read(); dec = json.JSONDecoder(); pos = 0; logs = []; seen = set()
while True:
    while pos < len(raw) and raw[pos].isspace():
        pos += 1
    if pos >= len(raw):
        break
    o, pos = dec.raw_decode(raw, pos)
    # Pages overlap on the boundary timestamp.
    if o.get("id") not in seen:
        seen.add(o.get("id")); logs.append(o)
# Android lines only. "profile" or "policy" alone would also match the Apple and Windows jobs.
keep = re.compile(r"android|pubsub|clouddpc|amapi|enterprises/", re.I)
# Timer chatter from the Android cron jobs, and the admin UI loading Android settings pages.
drop = re.compile(r"remaining until next tick|tick received|wait remaining|component=http user=(?!unauthenticated)", re.I)
masks = [
    (re.compile(r"(token=)[^&\s\"]+"), r"\1<token>"),
    (re.compile(r" instanceID=\"[^\"]*\""), ""),
]
n = 0
for l in logs:
    msg = l.get("message", "")
    if keep.search(msg) and not drop.search(msg):
        for rx, rep in masks:
            msg = rx.sub(rep, msg)
        print(l.get("timestamp", ""), msg)
        n += 1
print("== %d Android lines of %d in the window" % (n, len(logs)))
'
