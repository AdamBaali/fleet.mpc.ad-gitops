#!/usr/bin/env bash
# Film or sample a phone screen with a Mac and an iPhone used as a camera (Continuity Camera), with a UTC clock burned
# into every frame. The clock is the point: it lets a video be lined up with Fleet's activity log and with watch scripts
# after the run. Used first for the Android PIN test, where adb can't see the setup wizard.
#
# Usage:
#   phone-cam.sh list                       camera names ffmpeg can see
#   phone-cam.sh preview [CAMERA]           live window to aim the camera. Close it or press q
#   phone-cam.sh record  ID [CAMERA]        video with the UTC clock burned in, and a live view while it records
#   phone-cam.sh frames  ID [CAMERA] [FPS]  one still every 1/FPS seconds, named by UTC time (default 1 a second)
#   phone-cam.sh still   VIDEO MM:SS OUT    one still from a recorded video, at an offset from its start
#
# CAMERA is a name substring and defaults to the first camera with "iPhone" in its name, so no device or owner name is
# written here. Output goes to <project>/private/video/<ID>/ when run from a test project, else ./private/video/<ID>/.
# That folder is git ignored on purpose: the camera also sees the room, the desk, and the phone's home screen. Choose
# and crop frames, and mask them with maskbox.swift, before any go into test-evidence/.
#
# Needs ffmpeg (brew install ffmpeg) and camera access for the terminal app (macOS asks on first use).
# Keep the iPhone locked, landscape off, close to the Mac, and on the same Apple Account with Wi-Fi and Bluetooth on.
#
# Test without a camera: PHONE_CAM_TEST=1 uses ffmpeg's test pattern, so the clock and file names can be checked.
set -euo pipefail

cmd="${1:-}"; shift || true
case "$(uname -s)" in
  Darwin) FONT="${PHONE_CAM_FONT:-/System/Library/Fonts/Supplemental/Arial.ttf}" ;;
  *)      FONT="${PHONE_CAM_FONT:-/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf}" ;;
esac

# avfoundation lists video devices first, then audio. Only the video block matters.
cameras() {
  ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 \
    | sed -n '/AVFoundation video devices/,/AVFoundation audio devices/p' \
    | sed -n 's/.*\] \[[0-9]*\] //p'
}

pick_camera() { # name substring -> full device name
  local want="${1:-iPhone}" found
  found=$(cameras | grep -iF -- "$want" | head -1 || true)
  [ -n "$found" ] || { echo "no camera matching \"$want\". Run: $0 list" >&2; exit 1; }
  printf '%s' "$found"
}

# Input arguments. Selecting by name matters: ffplay and ffmpeg number cameras differently, so an index can pick the
# wrong one. ffmpeg keeps the camera open; reopening it per frame managed one frame every 16 seconds.
input_args() { # camera substring, fps
  if [ "${PHONE_CAM_TEST:-0}" = 1 ]; then
    echo "-f lavfi -i testsrc2=size=1080x1920:rate=30"
  else
    local cam; cam=$(pick_camera "${1:-iPhone}")
    echo "-f avfoundation -framerate 30 -i ${cam// /\\ }:none"
  fi
}

outdir() {
  local base="$PWD"
  # Inside testing/<project>/... use that project's private folder.
  case "$PWD" in */testing/*) base="${PWD%%/testing/*}/testing/$(echo "${PWD#*/testing/}" | cut -d/ -f1)" ;; esac
  mkdir -p "$base/private/video/$1"; echo "$base/private/video/$1"
}

# ffmpeg's drawtext treats ':' and '\' as separators, so the clock format is escaped for it.
clock="drawtext=fontfile=${FONT}:text='%{gmtime\\:%Y-%m-%d %H\\\\\\:%M\\\\\\:%S} UTC':x=20:y=20:fontsize=44:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=8"

case "$cmd" in
  list)
    cameras ;;
  preview)
    cam=$(pick_camera "${1:-iPhone}")
    exec ffplay -hide_banner -loglevel error -f avfoundation -framerate 30 -i "$cam:none" \
      -window_title "camera preview: $cam" -x 540 -y 960 ;;
  record)
    id="${1:?usage: phone-cam.sh record ID [CAMERA]}"; out="$(outdir "$id")"
    f="$out/$(date -u +%Y%m%dT%H%M%SZ).mp4"
    echo "recording to $f. Live view opens in a window. q in this terminal or Ctrl-C stops the recording"
    # Mute the Mac for the run (restored after) so the Continuity Camera chime stays out of the room.
    if [ "$(uname -s)" = Darwin ]; then
      was=$(osascript -e 'output muted of (get volume settings)'); osascript -e 'set volume output muted true'
      trap 'osascript -e "set volume output muted $was" >/dev/null 2>&1' EXIT
    fi
    # One camera open, two outputs: the file, and a low-delay stream for the live view. ffplay can't open the camera
    # while ffmpeg has it, so the view comes through a pipe. The viewer drains the pipe after its window closes, so
    # closing the window doesn't stop the recording.
    view="${PHONE_CAM_VIEW:-ffplay -hide_banner -loglevel error -fflags nobuffer -flags low_delay -window_title live-view -x 540 -y 960 -i -}"
    # veryfast and yuv420p so the file plays in QuickTime and a browser. crf 23 keeps 10 minutes near 100 MB.
    # shellcheck disable=SC2046,SC2086
    ffmpeg -hide_banner -loglevel warning -stats $(input_args "${2:-iPhone}") \
      -filter_complex "[0:v]${clock},split=2[rec][view]" \
      -map "[rec]" -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart \
      ${PHONE_CAM_SECONDS:+-t "$PHONE_CAM_SECONDS"} "$f" \
      -map "[view]" -c:v mpeg4 -q:v 6 ${PHONE_CAM_SECONDS:+-t "$PHONE_CAM_SECONDS"} -f nut - | { $view; cat >/dev/null; } ;;
  frames)
    id="${1:?usage: phone-cam.sh frames ID [CAMERA] [FPS]}"; fps="${3:-1}"; out="$(outdir "$id")"
    echo "frames at ${fps}/s to $out (q or Ctrl-C to stop)"
    # TZ=UTC makes -strftime name the files in UTC, like the watch timelines.
    # shellcheck disable=SC2046
    TZ=UTC exec ffmpeg -hide_banner -loglevel warning -stats $(input_args "${2:-iPhone}") \
      -vf "fps=$fps" -q:v 3 -strftime 1 ${PHONE_CAM_SECONDS:+-t "$PHONE_CAM_SECONDS"} "$out/%Y%m%dT%H%M%SZ.jpg" ;;
  still)
    v="${1:?usage: phone-cam.sh still VIDEO MM:SS OUT}"; t="${2:?offset}"; o="${3:?output file}"
    ffmpeg -hide_banner -loglevel error -y -ss "00:$t" -i "$v" -frames:v 1 -q:v 2 "$o" && echo "$o" ;;
  *)
    sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
