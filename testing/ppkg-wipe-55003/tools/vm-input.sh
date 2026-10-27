#!/bin/bash
# Keyboard and mouse input to a UTM VM through UTM's scripting (QEMU backend), so setup screens can be driven with no
# guest agent. Scan codes are PC AT set 1 (make, then break = make + 128).
#   tools/vm-input.sh <vm> shell          Shift+F10 (command prompt during Windows setup)
#   tools/vm-input.sh <vm> type "<text>"  type ASCII text
#   tools/vm-input.sh <vm> run "<cmd>"    type a command and press Enter
#   tools/vm-input.sh <vm> ps "<script>"  run PowerShell, sent base64-encoded: the golden VM's keyboard is UK layout, so
#                                         " | \ @ ~ # arrive as other characters; base64 letters, digits, + / = don't
#   tools/vm-input.sh <vm> key enter|tab|esc|win|f10|space
#   tools/vm-input.sh <vm> click <x> <y>  left click at screen coordinates of the guest display
set -euo pipefail
VM="$1"; ACT="$2"; shift 2
sc() { osascript -e "tell application \"UTM\" to input scan code (get virtual machine named \"$VM\") codes {$1}"; }
ty() { local t="${1//\\/\\\\}"; t="${t//\"/\\\"}"; osascript -e "tell application \"UTM\" to input keystroke (get virtual machine named \"$VM\") text \"$t\""; }
case "$ACT" in
  shell) sc "42, 68, 196, 170" ;;
  type)  ty "$1" ;;
  run)   ty "$1"; sleep 0.3; sc "28, 156" ;;
  ps)    b=$(printf '%s' "$1" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')
         ty "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand $b"; sleep 0.3; sc "28, 156" ;;
  key) case "$1" in
         enter) sc "28, 156" ;; tab) sc "15, 143" ;; esc) sc "1, 129" ;; space) sc "57, 185" ;;
         f10) sc "68, 196" ;; win) sc "224, 91, 224, 219" ;; *) echo "unknown key $1"; exit 1 ;;
       esac ;;
  click) osascript -e "tell application \"UTM\" to input mouse click (get virtual machine named \"$VM\") at {$1, $2}" ;;
  *) echo "unknown action $ACT"; exit 1 ;;
esac
