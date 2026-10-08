#!/usr/bin/env bash
# Run the sign-in from inside the Linux test VM (host C) and print the result line.
U=/Applications/UTM.app/Contents/MacOS/utmctl; LAB="$(cd "$(dirname "$0")/.." && pwd)"
$U exec lab-linux --cmd /bin/bash /opt/company/run-signin.sh
for i in 1 2 3 4 5 6; do sleep 4; out=$($U file pull lab-linux /tmp/signin.out 2>/dev/null); echo "$out" | grep -q "curl exit" && break; done
echo "$out" | grep -E "final_url" | sed -E 's/&state=lab//; s/code=[A-Za-z0-9_-]+/code=<redacted>/'
