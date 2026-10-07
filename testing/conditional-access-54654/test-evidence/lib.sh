#!/bin/bash
# Evidence helpers for the Linux A-to-Z run (#54654). Source from a script or call via `bash -c '. evidence/lib.sh; ...'`.
LAB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EV="$LAB/evidence/linux"
U=/Applications/UTM.app/Contents/MacOS/utmctl
set -a; . "$LAB/.env"; set +a
PUBIP="${LAB_PUBLIC_IP:-0.0.0.0}"

redact() { python3 "$LAB/evidence/redact.py" "$LAB/.env" "$PUBIP"; }

_dir() { ls -d "$EV/$1"-* 2>/dev/null | head -1; }
_n() { ls "$(_dir "$1")" | grep -E '^[0-9]{2}-' | wc -l | tr -d ' '; }
ev_init() { # id, title, objective, expected
  local d="$EV/$1-$(echo "$2" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-' | cut -c1-40)"; mkdir -p "$d"
  { echo "# $1: $2"; echo; echo "- **Started:** $(date -u +%FT%TZ)"; echo "- **Objective:** $3"; echo "- **Expected:** $4"; echo; echo "## Steps and evidence"; } > "$d/result.md"
  echo "$d"
}
ev_cmd() { # id, label, command (runs on the Mac)
  local d; d=$(_dir "$1"); local n; n=$(printf '%02d' $(( $(_n "$1") + 1 ))); local f="$d/$n-$2.txt"
  { echo "# $(date -u +%FT%TZ)"; echo "\$ $3"; echo; bash -c "$3" 2>&1; } | redact > "$f"
  echo "- \`$n-$2.txt\`: \`$(echo "$3" | cut -c1-110)\`" >> "$d/result.md"
  cat "$f"
}
ev_vm() { # id, label, command (runs as root in the Linux VM)
  local d; d=$(_dir "$1"); local n; n=$(printf '%02d' $(( $(_n "$1") + 1 ))); local f="$d/$n-$2.txt"
  { echo "# $(date -u +%FT%TZ) (in the Linux VM lab-linux, as root)"; echo "\$ $3"; echo; bash "$LAB/vm/linux/vm-run.sh" "$3" 2>&1; } | redact > "$f"
  echo "- \`$n-$2.txt\` (VM): \`$(echo "$3" | cut -c1-110)\`" >> "$d/result.md"
  cat "$f"
}
ev_shot() { # id, label  (screenshot from inside the VM)
  local d; d=$(_dir "$1"); local n; n=$(printf '%02d' $(( $(_n "$1") + 1 ))); local f="$d/$n-$2.png"
  bash "$LAB/vm/linux/vm-run.sh" 'bash /tmp/shot.sh' >/dev/null 2>&1; $U file pull lab-linux /tmp/shot.png > "$f" 2>/dev/null
  echo "- \`$n-$2.png\` (VM screenshot)" >> "$d/result.md"; echo "$f"
}
ev_note() { local d; d=$(_dir "$1"); echo "" >> "$d/result.md"; echo "$2" >> "$d/result.md"; }
ev_verdict() { # id, PASS|FAIL|PARTIAL|NOT-RUN, note
  local d; d=$(_dir "$1"); { echo; echo "## Result: **$2**"; echo; echo "$3"; echo; echo "_Finished $(date -u +%FT%TZ)_"; } >> "$d/result.md"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$(basename "$d")" "$3" >> "$EV/results.tsv"
}

# --- UTM input helpers for the Linux VM (lab-linux) ---
VMID="86D7DC8E-3373-47AF-86DD-56A1CD517E2F"
utm_type()  { osascript -e "tell application \"UTM\" to input keystroke (virtual machine id \"$VMID\") text \"$1\"" 2>&1 | tail -1; }
utm_codes() { osascript -e "tell application \"UTM\" to input scan code (virtual machine id \"$VMID\") codes {$1}" 2>&1 | tail -1; }
utm_click() { osascript -e "tell application \"UTM\" to input mouse click (virtual machine id \"$VMID\") at {$1, $2}" 2>&1 | tail -1; }
