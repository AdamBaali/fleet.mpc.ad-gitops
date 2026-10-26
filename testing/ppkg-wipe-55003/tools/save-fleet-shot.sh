#!/bin/bash
# Copies the newest Chrome-extension screenshot (a Fleet UI page) into a test's evidence folder with a label, and lists
# it in result.md. The Mac's window capture can't see the Chrome window, so Fleet pages are captured by the extension.
# Usage: tools/save-fleet-shot.sh <test-id> <label>
set -euo pipefail
ID="$1"; LABEL="$2"
SRC=$(ls -t "$HOME"/.claude/projects/-Users-adam-Documents-GitHub-fleet-mpc-ad-gitops/*/tool-results/mcp-claude-in-chrome-blob-*.jpg | head -1)
D=$(ls -d test-evidence/*/"$ID"-* | head -1)
N=$(printf '%02d' $(( $(ls "$D" | grep -cE '^[0-9]{2}-') + 1 )))
cp "$SRC" "$D/$N-$LABEL.jpg"
echo "- \`$N-$LABEL.jpg\` (Fleet UI, Chrome)" >> "$D/result.md"
echo "$D/$N-$LABEL.jpg"
