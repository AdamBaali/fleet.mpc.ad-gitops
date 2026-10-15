#!/usr/bin/env bash
# After tests/banner-dialog.sh: put the lab zenity wrapper back, request escrow again, wait for the new key slot and Fleet "verified", refresh the stored escrow key.
set -uo pipefail
cd "$(dirname "$0")/.."; VM=luks-ubuntu; set -a; . ./.env; set +a
tools/vm-run.sh $VM '[ -f /usr/local/bin/zenity.lab-wrapper ] && mv /usr/local/bin/zenity.lab-wrapper /usr/local/bin/zenity; type -a zenity | head -1' | head -1
tools/vm-run.sh $VM "T=\$(cat /opt/orbit/identifier); curl -s -o /dev/null -w 'trigger_escrow: HTTP %{http_code}\n' -X POST \"$FLEET_URL/api/latest/fleet/device/\$T/mdm/linux/trigger_escrow\"" | head -1
for i in $(seq 1 40); do n=$(tools/vm-run.sh $VM 'cryptsetup luksDump /dev/nvme0n1p3 | grep -cE "^  [0-9]+: luks2"' 2>/dev/null | head -1); [ "$n" -ge 2 ] 2>/dev/null && { echo "keyslots: $n"; break; }; sleep 20; done
sleep 25; tools/fleetapi.py /api/latest/fleet/hosts/17/encryption_key | python3 -I -c "import json,sys; sys.stdout.write(json.load(sys.stdin)['encryption_key']['key'])" > secrets/escrow-key.txt; chmod 600 secrets/escrow-key.txt
U=/Applications/UTM.app/Contents/MacOS/utmctl; $U file push $VM /tmp/.esc < secrets/escrow-key.txt >/dev/null 2>&1; tools/vm-run.sh $VM 'install -m 0600 /tmp/.esc /root/.escrowkey; rm -f /tmp/.esc /root/.tmpk; printf "new escrow key opens: "; cryptsetup open --test-passphrase /dev/nvme0n1p3 --key-file /root/.escrowkey >/dev/null 2>&1 && echo YES || echo NO' | head -1
echo "fleet: $(tools/fleetapi.py /api/latest/fleet/hosts/17 | python3 -I -c "import json,sys; m=json.load(sys.stdin)['host'].get('mdm') or {}; print((m.get('os_settings') or {}).get('disk_encryption',{}).get('status'))")"
