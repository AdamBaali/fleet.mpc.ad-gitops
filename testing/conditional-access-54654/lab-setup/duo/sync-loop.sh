#!/bin/bash
# D-12: run duo/sync.sh every 5 minutes until stopped (kill the process or remove duo/sync.run).
LAB="$(cd "$(dirname "$0")/.." && pwd)"
touch "$LAB/duo/sync.run"
while [ -e "$LAB/duo/sync.run" ]; do bash "$LAB/duo/sync.sh" >> "$LAB/duo/sync.log" 2>&1; sleep 300; done
