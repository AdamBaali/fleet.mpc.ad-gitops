#!/usr/bin/env bash
# Evidence helpers. Source this file:  . testing/_framework/bin/ev.sh
# Layout it produces:  <EV>/<ID>-<slug>/result.md  +  NN-<label>.txt (outputs)  +  NN-<label>.png (pictures)
# Set EV (evidence root) and optionally SECRETS_ENV (a file whose KEY=VALUE secrets are masked in outputs).
: "${EV:?set EV to the evidence folder, for example EV=\$PWD/evidence/macos}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_dir()  { ls -d "$EV/$1"-* 2>/dev/null | head -1; }
_n()    { ls "$(_dir "$1")" 2>/dev/null | grep -cE '^[0-9]{2}-'; }
redact(){ python3 "$HERE/redact.py" ${SECRETS_ENV:-/dev/null} "$@"; }

ev_init() { # id, title, objective, expected  -> creates the test folder and result.md
  local d="$EV/$1-$(echo "$2" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-' | cut -c1-40)"; mkdir -p "$d"
  { echo "# $1: $2"; echo; echo "- **Started:** $(date -u +%FT%TZ)"; echo "- **Objective:** $3"; echo "- **Expected:** $4"; echo; echo "## Steps and evidence"; } > "$d/result.md"
  echo "$d"
}
ev_cmd() { # id, label, command  -> runs it, saves the redacted output as NN-label.txt and lists it in result.md
  local d n f; d=$(_dir "$1"); n=$(printf '%02d' $(( $(_n "$1") + 1 ))); f="$d/$n-$2.txt"
  { echo "# $(date -u +%FT%TZ)"; echo "\$ $3"; echo; bash -c "$3" 2>&1; echo "[exit $?]"; } | redact > "$f"
  echo "- \`$n-$2.txt\`: \`$(echo "$3" | cut -c1-110)\`" >> "$d/result.md"; cat "$f"
}
ev_shot() { # id, label, [window-owner-app]  -> window-only screenshot as NN-label.png (never the whole screen)
  local d n f w; d=$(_dir "$1"); n=$(printf '%02d' $(( $(_n "$1") + 1 ))); f="$d/$n-$2.png"
  w=$("${WINID:-winid}" "${3:-Google Chrome}") || { echo "no window for ${3:-Google Chrome}" >&2; return 1; }
  screencapture -x -o -l"$w" "$f"; echo "- \`$n-$2.png\` (window screenshot)" >> "$d/result.md"; echo "$f"
}
ev_note() { local d; d=$(_dir "$1"); printf '\n%s\n' "$2" >> "$d/result.md"; }
ev_verdict() { # id, PASS|FAIL|PARTIAL|NOT-RUN|BLOCKED|INFO, note  -> the line the index reads
  local d; d=$(_dir "$1"); { printf '\n## Result: %s\n\n%s\n\n_Finished %s_\n' "$2" "$3" "$(date -u +%FT%TZ)"; } >> "$d/result.md"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$(basename "$d")" "$3" >> "$EV/results.tsv"
}
