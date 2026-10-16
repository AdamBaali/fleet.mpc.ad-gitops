#!/bin/bash
# One-screen health check of the lab. Prints no secrets.
cd "$(dirname "$0")/.." || exit 1
set -a; . ./.env; set +a
ok(){ printf '  %-34s %s\n' "$1" "$2"; }
echo "== Lab status $(date -u +%FT%TZ)"
for c in stepca pingfederate; do ok "docker $c" "$(docker ps --format '{{.Names}} {{.Status}}' | grep "^$c " | cut -d' ' -f2- || true)"; done
ok "cloudflared tunnel" "$(pgrep -f 'cloudflared tunnel' >/dev/null && echo running || echo NOT running)"
ok "SCEP via tunnel" "$(curl -s -o /dev/null -m 8 -w '%{http_code}' 'https://scep.mpc.ad/scep/fleet-scep?operation=GetCACaps')"
ok "Fleet" "$(curl -s -o /dev/null -m 8 -w '%{http_code}' "$FLEET_URL/healthz")"
ok "PingFederate admin" "$(curl -sk -o /dev/null -m 8 -w '%{http_code}' https://localhost:9999/pingfederate/app)"
ok "PingFederate runtime 9031/9032" "$(nc -z -w2 localhost 9031 2>/dev/null && echo up || echo down) / $(nc -z -w2 localhost 9032 2>/dev/null && echo up || echo down)"
ok "Duo demo (8443)" "$(nc -z -w2 localhost 8443 2>/dev/null && echo up || echo down)"
ok "Duo sync loop" "$(pgrep -f 'duo/sync-loop.sh' >/dev/null && echo running || echo stopped)"
ok "UTM lab-linux" "$(/Applications/UTM.app/Contents/MacOS/utmctl list 2>/dev/null | awk '/lab-linux/{print $2}')"
ok "/etc/hosts ping.lab" "$(grep -c ping.lab /etc/hosts) entry"
ok "Mac sleep prevention" "$(pmset -g assertions 2>/dev/null | grep -c 'PreventUserIdleSystemSleep.*1') active"
echo "== Fleet hosts"
fleetctl api -F per_page=20 /hosts 2>/dev/null | jq -r '.hosts[]|"  \(.id) \(.hostname) \(.platform) seen \(.seen_time[0:16])"' | grep -v ' ios '
