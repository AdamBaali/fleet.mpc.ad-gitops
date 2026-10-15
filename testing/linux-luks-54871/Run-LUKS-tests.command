#!/bin/bash
# Double-click this in Finder. It runs every remaining Linux LUKS test end to end and opens the results when done.
# It starts the disk unlock watcher itself (that part types the disk passphrase for the test VM). Keep Amphetamine on. About 15 minutes.
cd "$(dirname "$0")" || exit 1
mkdir -p logs
echo "Linux LUKS lab: running all remaining tests. Log: logs/run-all.log"
bash tests/run-all.sh 2>&1 | tee logs/run-all.log
echo; echo "Finished. You can close this window."; read -r -t 30 -p "Press Return to close (closes by itself in 30 s) " _ || true
