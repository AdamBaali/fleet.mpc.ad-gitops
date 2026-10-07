#!/bin/bash
# Lab sync (D-12): export Fleet hosts with the guide's export script, then upload each list to its Duo integration.
# Run by launchd every 5 minutes. Secrets come from ../.env and ../secrets/duo; nothing is printed except counts.
set -uo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"
cd "$LAB/duo/run" || exit 1
set -a; . "$LAB/.env"; set +a
log() { echo "$(date -u +%FT%TZ) $*"; }
sed -e 's#https://fleet.example.com#https://fleet.mpc.ad#' -e 's#<Windows-MachineGuid-report-ID>#69#' \
  "$LAB/fleet/docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh" > export-guide.sh
if ! FLEET_API_TOKEN="$FLEET_TOKEN_DUO" bash export-guide.sh >/dev/null 2>export.err; then
  log "export FAILED: $(tr '\n' ' ' <export.err | cut -c1-200)"; exit 1
fi
for os in macos windows linux; do
  n=$(( $(wc -l < "$os.csv") - 1 ))
  if [ "$n" -lt 1 ]; then log "$os: no hosts, skipped"; continue; fi
  if out=$("$LAB/.venv/bin/python" "$LAB/secrets/duo/$os/device_cache_sync.py" --infile "$os.csv" --device_id_column device_id 2>&1); then
    log "$os: $n synced"
  else
    log "$os: sync FAILED: $(echo "$out" | tail -2 | tr '\n' ' ' | cut -c1-200)"
  fi
done
