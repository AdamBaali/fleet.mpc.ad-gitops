#!/usr/bin/env bash
# Duo Universal Prompt demo for the lab VMs. The VMs reach it at https://ping.lab:8443
# (ping.lab -> 192.168.64.1 in each VM; step-ca root trusted there). Duo requires an https
# redirect_uri with a hostname, not an IP. Bound to the VM bridge only, so start a VM first
# (the bridge100 interface exists only while a shared-network VM runs).
# Usage: duo/start-demo.sh [stop]
LAB="$(cd "$(dirname "$0")/.." && pwd)"; cd "$LAB/duo/demo/demo"
if [ "${1:-}" = stop ]; then pkill -f "flask run --host=192.168.64.1" && echo stopped; exit 0; fi
ifconfig bridge100 2>/dev/null | grep -q "inet 192.168.64.1" || { echo "bridge100 not up: start a VM first" >&2; exit 1; }
nohup "$LAB/.venv/bin/flask" --app app run --host=192.168.64.1 --port 8443 \
  --cert "$LAB/ping/certs/ping.lab.crt" --key "$LAB/ping/certs/ping.lab.key" > "$LAB/duo/demo.log" 2>&1 &
sleep 3; curl -s -o /dev/null -w "demo: https://ping.lab:8443 -> HTTP %{http_code}\n" --cacert "$LAB/ping/certs/step-ca-root.crt" --resolve ping.lab:8443:192.168.64.1 https://ping.lab:8443/
