#!/usr/bin/env bash
# Drive a UTM VM from the host: window-only screenshots, keystrokes and clicks.
# usage: tools/utm-vm.sh <vm> shot <out.png>
#        tools/utm-vm.sh <vm> type '<text>'      (use \n for Return, \t for Tab)
#        tools/utm-vm.sh <vm> click <x> <y>      (guest screen pixels)
# Secrets are never passed on the command line: use `typesecret <ENV_NAME>`, which reads .env.
HERE="$(cd "$(dirname "$0")" && pwd)"; VM="$1"; CMD="$2"; shift 2
case "$CMD" in
  shot)
    WID=$(swift "$HERE/screens/winid.swift" UTM "$VM") || { echo "no UTM window for $VM" >&2; exit 1; }
    screencapture -x -o -l"$WID" "$1"; echo "saved $1 (window $WID)";;
  type)
    osascript -e "tell application \"UTM\" to input keystroke (get virtual machine named \"$VM\") text \"$(printf '%b' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g')\"";;
  click)
    osascript -e "tell application \"UTM\" to input mouse click (get virtual machine named \"$VM\") at {$1, $2}";;
  clickd)
    # coordinates as seen in a 2000px-wide window screenshot; converts to guest pixels
    X=$(awk -v x="$1" 'BEGIN{printf "%d", x*0.64}'); Y=$(awk -v y="$2" 'BEGIN{printf "%d", (y-59)*0.64}')
    osascript -e "tell application \"UTM\" to input mouse click (get virtual machine named \"$VM\") at {$X, $Y}";;
  *) echo "unknown command $CMD" >&2; exit 2;;
esac
