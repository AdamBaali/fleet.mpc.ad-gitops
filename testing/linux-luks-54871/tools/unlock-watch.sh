#!/usr/bin/env bash
# RUN THIS YOURSELF in a terminal (not from Claude). It types the disk passphrase at the unlock prompt each time the VM boots,
# so reboot tests can run with nobody at the screen. Leave it running; Ctrl-C stops it.
# usage: tools/unlock-watch.sh <vm> --live          types the first line of secrets/unlock-passphrase, re-read at EVERY boot (so the key can be swapped without restarting this)
#        tools/unlock-watch.sh <vm> [SECRET_NAME]        SECRET_NAME is a variable in .env (default LUKS_USER_PASSPHRASE).
#        tools/unlock-watch.sh <vm> --file <path>        types the first line of a file (for example an escrowed key you saved with pbpaste)
# Nothing is printed except "unlock typed for <vm> at <time>". The passphrase is never echoed.
set -uo pipefail
VM="${1:?usage: unlock-watch.sh <vm> [SECRET_NAME | --file path]}"; SRC="${2:-LUKS_USER_PASSPHRASE}"
cd "$(dirname "$0")/.."
getpass() { if [ "$SRC" = "--file" ]; then head -n1 "${3:?path}" | tr -d '\n'; else grep "^$SRC=" .env | cut -d= -f2- | tr -d '\n'; fi; }
if [ "$SRC" = "--live" ]; then getlive(){ head -n1 secrets/unlock-passphrase | tr -d "\n"; }; PASS="$(getlive)"; else PASS="$(getpass "$@")"; fi; [ -n "$PASS" ] || { echo "no passphrase found"; exit 1; }
DELAY="${UNLOCK_DELAY:-40}"   # seconds after boot before typing (the unlock prompt appears about 20-40 s after start)
prev="$(utmctl status "$VM" 2>&1)"
echo "watching $VM (state: $prev). Typing the passphrase ${DELAY}s after each boot. Ctrl-C to stop."
while sleep 2; do
  now="$(utmctl status "$VM" 2>&1)"
  if [ "$now" = "started" ] && [ "$prev" != "started" ]; then
    sleep "$DELAY"
    [ "$SRC" = "--live" ] && PASS="$(getlive)"
    osascript -e "tell application \"UTM\" to input keystroke (get virtual machine named \"$VM\") text \"$(printf '%s' "$PASS" | sed 's/\\/\\\\/g;s/"/\\"/g')\n\"" >/dev/null 2>&1
    echo "unlock typed for $VM at $(date +%H:%M:%S)"
  fi
  prev="$now"
done
