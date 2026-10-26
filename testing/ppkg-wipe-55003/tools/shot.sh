#!/bin/bash
# Window-only screenshot into a test's evidence folder, and a line in its result.md. Never the whole screen.
#   tools/shot.sh <test-id> <label> <app> [window-title-part]
#   tools/shot.sh E-1 region-screen UTM e1-bypass
#   tools/shot.sh E-1 fleet-host "Google Chrome"
# Run from the project folder. Needs winid (testing/_framework/tools, built into ~/.local/bin).
set -euo pipefail
ID="$1"; LABEL="$2"; APP="$3"; TITLE="${4:-}"
WINID="${WINID:-$(command -v winid || echo "$HOME/.local/bin/winid")}"
D=$(ls -d test-evidence/*/"$ID"-* 2>/dev/null | head -1); [ -n "$D" ] || { echo "no evidence folder for $ID (run ev_init first)"; exit 1; }
N=$(printf '%02d' $(( $(ls "$D" | grep -cE '^[0-9]{2}-') + 1 )))
W=$("$WINID" "$APP" "$TITLE") || { echo "no window for $APP $TITLE"; exit 1; }
screencapture -x -o -l"$W" "$D/$N-$LABEL.png"
echo "- \`$N-$LABEL.png\` (window screenshot: $APP${TITLE:+ / $TITLE})" >> "$D/result.md"
echo "$D/$N-$LABEL.png"
