#!/bin/bash
# Double-click (or: bash Run-LUKS-extra.command). Runs the #35241 extra tests end to end (about 20 minutes, three cold restarts of luks-ubuntu).
# It starts the disk unlock watcher itself: that part types the lab disk passphrase. Keep Amphetamine on.
cd "$(dirname "$0")" || exit 1
mkdir -p logs
echo "Linux LUKS lab: extra tests. Log: logs/run-extra.log"
SKIP_K13=1 bash tests/run-extra.sh 2>&1 | tee logs/run-extra.log
echo; echo "Finished."; read -r -t 30 -p "Press Return to close " _ || true
