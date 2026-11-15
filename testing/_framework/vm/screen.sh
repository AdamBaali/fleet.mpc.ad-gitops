#!/bin/bash
# Read a VM's screen on the Mac, without sending pictures to the model unless it needs one.
# OCR runs locally (tesseract), so waiting for a screen costs no tokens: Claude gets one line of text, not 60 images.
#
# Usage: screen.sh <vm> look <out.png> [width]     screenshot scaled to width (default 1024) for Claude to read
#        screen.sh <vm> text                       the words on screen, one line per text line
#        screen.sh <vm> find '<text>'              x y of the text's centre, in screenshot pixels (exit 1 if absent)
#        screen.sh <vm> click '<text>'             find, then click it through qmp.sh
#        screen.sh <vm> wait '<regex>' [timeout s] [interval s]   until the screen shows text matching regex
#        screen.sh <vm> still [stable s] [timeout s]              until the screen stops changing
# wait and still keep the last frame in $SCREEN_DIR (default out/screen/<vm>/) and print its path.
# Needs tesseract and Pillow (see ocr.py). SHOT_CMD='cp some.png' replaces the QMP screendump, for tests.
set -euo pipefail
vm=$1 cmd=$2; shift 2
here=$(cd "$(dirname "$0")" && pwd)
dir=${SCREEN_DIR:-${VM_ROOT:-$PWD/out/qemu}/../screen/$vm}; mkdir -p "$dir"

shot() { # out.png
  if [ -n "${SHOT_CMD:-}" ]; then $SHOT_CMD "$1"; else "$here/qmp.sh" "$vm" shot "$1" >/dev/null; fi
}
ocr() { python3 -I "$here/ocr.py" "$@"; }

case $cmd in
  look)  t="$dir/.look.png"; shot "$t"; ocr small "$t" "$1" "${2:-1024}" ;;
  text)  t="$dir/.cur.png"; shot "$t"; ocr text "$t" ;;
  find)  t="$dir/.cur.png"; shot "$t"; ocr find "$t" "$1" ;;
  click) xy=$("$0" "$vm" find "$1") || { echo "\"$1\" not on screen" >&2; exit 1; }
         [ -n "${SHOT_CMD:-}" ] && { echo "click $xy"; exit 0; }
         "$here/qmp.sh" "$vm" click $xy ;;
  wait)  re=$1 end=$(( $(date +%s) + ${2:-600} )) every=${3:-10}
         while :; do
           f="$dir/$(date -u +%H%M%S).png"; shot "$f"
           if hit=$(ocr match "$f" "$re"); then echo "found: $hit"; echo "$f"; exit 0; fi
           [ "$(date +%s)" -ge "$end" ] && { echo "timeout waiting for /$re/" >&2; echo "$f"; exit 1; }
           rm -f "$f"; sleep "$every"
         done ;;
  still) need=${1:-30} end=$(( $(date +%s) + ${2:-900} )) last="" since=$(date +%s)
         while [ "$(date +%s)" -lt "$end" ]; do
           f="$dir/still.png"; shot "$f"; sum=$(cksum < "$f")
           [ "$sum" != "$last" ] && { last=$sum; since=$(date +%s); }
           [ $(( $(date +%s) - since )) -ge "$need" ] && { echo "$f"; exit 0; }
           sleep 5
         done; echo "screen still changing" >&2; echo "$f"; exit 1 ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
