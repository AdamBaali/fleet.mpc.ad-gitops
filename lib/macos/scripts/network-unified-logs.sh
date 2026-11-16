#!/bin/bash
# Collects network evidence from the Apple unified log for pages that fail to load.
# Fleet keeps only 10,000 characters of script output, so this prints a summary and
# saves the full log on the Mac for a later pull.
# Read-only: it changes no settings.

HOURS="${HOURS:-2}"
OUT_DIR="/Library/Logs/fleet-net-diag"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FULL="$OUT_DIR/network-$STAMP.log"
mkdir -p "$OUT_DIR"

# Wi-Fi link changes, network stack errors, DNS errors, and QUIC. Info and debug
# messages from these subsystems are too many to fit; errors and faults carry the signal.
PRED='(subsystem == "com.apple.network" AND (messageType == error OR messageType == fault))
 OR (process == "mDNSResponder" AND (messageType == error OR messageType == fault))
 OR (subsystem == "com.apple.wifi" AND (eventMessage CONTAINS[c] "roam" OR eventMessage CONTAINS[c] "disassoc" OR eventMessage CONTAINS[c] "link down" OR eventMessage CONTAINS[c] "link up"))
 OR (eventMessage CONTAINS[c] "quic" AND (messageType == error OR messageType == fault))'

log show --last "${HOURS}h" --style compact --predicate "$PRED" > "$FULL" 2>/dev/null

echo "== host $(scutil --get ComputerName) | last ${HOURS}h | macOS $(sw_vers -productVersion)"
echo "== full log: $FULL ($(wc -l < "$FULL" | tr -d ' ') lines)"
echo "== Wi-Fi: $(ipconfig getsummary en0 2>/dev/null | awk -F' : ' '/ SSID /{print $2; exit}') | router $(route -n get default 2>/dev/null | awk '/gateway/{print $2}')"

echo "== counts"
printf "network errors:  %s\n" "$(grep -c 'com.apple.network' "$FULL")"
printf "dns errors:      %s\n" "$(grep -c 'mDNSResponder' "$FULL")"
printf "quic errors:     %s\n" "$(grep -ci 'quic' "$FULL")"
printf "wifi roams:      %s\n" "$(grep -ci 'roam' "$FULL")"
printf "wifi link drops: %s\n" "$(grep -ciE 'disassoc|link down' "$FULL")"

# Strip timestamps, pids, hex, and numbers so repeats of one error group together.
echo "== top repeated errors"
cut -c 25- "$FULL" | sed -E 's/\[[0-9]+:[0-9]+\]//g; s/0x[0-9a-f]+/0x_/g; s/[0-9]+/N/g' \
  | cut -c 1-160 | sort | uniq -c | sort -rn | head -20

echo "== processes with the most errors"
awk '{print $4}' "$FULL" | sed -E 's/\[.*//' | sort | uniq -c | sort -rn | head -10

echo "== last 15 Wi-Fi link events"
grep -iE 'roam|disassoc|link down|link up' "$FULL" | tail -15 | cut -c 1-200

echo "== last 15 QUIC errors"
grep -i 'quic' "$FULL" | tail -15 | cut -c 1-200

# Keep a week of runs so the folder doesn't grow without limit.
find "$OUT_DIR" -name 'network-*.log' -mtime +7 -delete 2>/dev/null
exit 0
