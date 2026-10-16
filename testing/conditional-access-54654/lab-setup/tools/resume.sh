#!/bin/bash
# Brings the lab back up after a reboot or a pause. Safe to run again. Then run tools/status.sh.
cd "$(dirname "$0")/.." || exit 1
set -a; . ./.env; set +a
echo "1/5 Docker (open Docker Desktop first if this fails)"
(cd stepca && docker compose --env-file ../.env up -d) 2>&1 | tail -2
(cd ping && docker compose --env-file ../.env up -d) 2>&1 | tail -2
echo "2/5 Cloudflare tunnel (SCEP for Fleet)"
pgrep -f 'cloudflared tunnel' >/dev/null || { nohup cloudflared tunnel --config cloudflared/config.yml run fleet-lab-scep > cloudflared/tunnel.log 2>&1 & sleep 5; }
echo "3/5 Linux VM"
/Applications/UTM.app/Contents/MacOS/utmctl list | grep -q 'lab-linux.*started\|started.*lab-linux' || /Applications/UTM.app/Contents/MacOS/utmctl start lab-linux
echo "4/5 Duo demo app (needs the VM bridge, so after the VM is up)"
sleep 20; bash duo/start-demo.sh 2>&1 | tail -1
echo "5/5 Duo sync every 5 minutes (stop: rm duo/sync.run)"
pgrep -f 'duo/sync-loop.sh' >/dev/null || nohup caffeinate -i bash duo/sync-loop.sh >/dev/null 2>&1 &
sleep 2; bash tools/status.sh
