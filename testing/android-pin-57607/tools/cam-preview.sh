#!/usr/bin/env bash
# Live preview of the camera cam-log.sh records, to line it up on the phone screen. Close the window or press q.
# Selects the camera by name: ffplay and ffmpeg number the cameras differently, so an index can pick the wrong one.
# Usage: cam-preview.sh [camera name, default "Adam’s iPhone Camera"]
set -euo pipefail
cam="${1:-Adam’s iPhone Camera}"
exec ffplay -hide_banner -loglevel error -f avfoundation -framerate 30 -i "$cam:none" \
  -window_title "camera preview: $cam" -x 540 -y 960
