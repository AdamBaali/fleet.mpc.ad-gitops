#!/bin/bash
# P-15 macOS watcher: every 5 minutes log the lab certificate(s) in the login keychain and the Fleet profile status.
LAB="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$LAB"
touch evidence/renewal/watch.run
while [ -e evidence/renewal/watch.run ]; do
  ts=$(date -u +%FT%TZ)
  n=$(security find-identity ~/Library/Keychains/login.keychain-db | grep -c EBC70)
  certs=$(python3 evidence/renewal/certinfo.py ~/Library/Keychains/login.keychain-db)
  st=$(fleetctl api /hosts/12 2>/dev/null | jq -r '[.host.mdm.profiles[]|select(.name=="Lab CA client certificate")|.status]|join(",")')
  echo "$ts identities=$n profile=$st | $certs" >> evidence/renewal/watch.log
  sleep 300
done
