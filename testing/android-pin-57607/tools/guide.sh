#!/usr/bin/env bash
# On-screen guide for one device run: the steps, a countdown before the QR scan, then a running clock in UTC and time
# since the scan (T0), so the person at the phone can read T+ off the screen. Pace "slow" adds a 2-minute countdown
# for the wait in O2-4. Silent: no terminal bell.
#
# Usage: guide.sh ID FLEET-NAME [normal|slow|fast]
# Keys while the clock runs: w starts the 2-minute wait (slow pace), q quits.
set -uo pipefail
id="${1:?usage: guide.sh ID FLEET [pace]}"; fleet="${2:?usage: guide.sh ID FLEET [pace]}"; pace="${3:-normal}"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
count() { # seconds, label
  local s=$1
  while [ "$s" -gt 0 ]; do printf '\r  %s: %3ds ' "$2" "$s"; sleep 1; s=$((s - 1)); done
  printf '\r  %s: now        \n' "$2"
}

clear
say "$id  fleet: $fleet  pace: $pace"
cat <<EOF
  1. Camera on the Samsung screen (tools/cam-preview.sh to check). Watcher and camera are already recording.
  2. Factory reset: Settings > General management > Reset > Factory data reset.
  3. On the welcome screen, tap 6 times. The QR reader opens.
  4. On the laptop: Hosts > $fleet > Add hosts > Android > Company-owned. Open the link in a new tab.
  5. When the QR reader is open, press Enter here, then scan within the countdown.
EOF
case "$pace" in
  normal) echo "  Pace: continue as soon as each screen allows." ;;
  slow)   echo "  Pace: after \"Getting your phone ready\", wait 2 minutes on the first screen that asks for input (press w)." ;;
  fast)   echo "  Pace: tap through every screen as soon as it allows." ;;
esac
read -r -p $'\n  Press Enter when the QR reader is open... ' _
count 10 "scan in"
t0=$(date -u +%s)
say "Scan now. T0 = $(date -u +%T) UTC. Tell Claude \"scanned\"."
echo "  Then say \"done\" at the home screen, or \"blocked\" with the exact text."
echo

waiting=0
while :; do
  now=$(date -u +%s); e=$((now - t0))
  line=$(printf '%s UTC   T+%02d:%02d' "$(date -u +%T)" $((e / 60)) $((e % 60)))
  if [ "$waiting" -gt 0 ]; then
    left=$((waiting - now)); [ "$left" -le 0 ] && { waiting=0; line="$line   wait over: continue"; } || line="$line   wait: ${left}s"
  fi
  printf '\r  %-60s' "$line"
  if read -r -s -n 1 -t 1 k; then
    case "$k" in
      w) waiting=$((now + 120)) ;;
      q) echo; exit 0 ;;
    esac
  fi
done
