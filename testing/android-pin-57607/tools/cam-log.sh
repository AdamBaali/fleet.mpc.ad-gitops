#!/usr/bin/env bash
# Takes a frame of the phone screen from a Mac camera every second, named by UTC time, so the setup wizard screens
# can be matched against the Fleet timeline (watch-host.sh) after the run. adb can't do this: a factory reset turns
# USB debugging off until setup finishes.
#
# Usage: cam-log.sh ID [camera name, default "Adam’s iPhone Camera"] [frames per second, default 1]
#        ffmpeg -f avfoundation -list_devices true -i "" lists the camera names. Stop with q or Ctrl-C.
# Frames go to private/cam/<ID>/ (git ignores private/): the camera also sees the room, so pick and crop frames
# before any go into test-evidence/.
# Needs ffmpeg (brew install ffmpeg) and camera access for the terminal app (macOS asks on first use).
# ffmpeg keeps the camera open. imagesnap reopened the iPhone camera for each frame and managed one every 16 seconds.
set -uo pipefail
id="${1:?usage: cam-log.sh ID [camera] [fps]}"; cam="${2:-Adam’s iPhone Camera}"; fps="${3:-1}"
out="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/private/cam/$id"; mkdir -p "$out"
echo "frames at ${fps}/s from \"$cam\" to private/cam/$id/ (q or Ctrl-C to stop)"
# TZ=UTC so -strftime names the files in UTC, like the watch timeline.
TZ=UTC exec ffmpeg -hide_banner -loglevel warning -stats \
  -f avfoundation -framerate 30 -i "$cam:none" \
  -vf "fps=$fps" -q:v 3 -strftime 1 "$out/%Y%m%dT%H%M%SZ.jpg"
