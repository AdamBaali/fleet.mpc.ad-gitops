#!/usr/bin/env bash
# Prints how far this machine's clock is from the Fleet server's, in seconds. Run it before any timed test.
# Why: tests line up host logs, phone video, and Fleet's activity log by UTC time. A Mac 12 s off made the first
# Android PIN run's timings wrong by that much.
# Usage: clock-check.sh [url]       default: $FLEET_URL
set -euo pipefail
url="${1:-${FLEET_URL:?set FLEET_URL or pass a url}}"
hdr=$(curl -sSI --max-time 10 "$url" | tr -d '\r' | awk -F': ' 'tolower($1)=="date"{print $2; exit}')
[ -n "$hdr" ] || { echo "no Date header from $url" >&2; exit 1; }
if date -d "$hdr" +%s >/dev/null 2>&1; then remote=$(date -d "$hdr" +%s)     # GNU date
else remote=$(date -j -u -f '%a, %d %b %Y %H:%M:%S GMT' "$hdr" +%s); fi      # BSD date on macOS
local_now=$(date -u +%s)
echo "server $hdr"; echo "local  $(date -u '+%a, %d %b %Y %H:%M:%S GMT')"
echo "local clock is $((local_now - remote)) s ahead of the server (negative means behind; the Date header is whole seconds)"
