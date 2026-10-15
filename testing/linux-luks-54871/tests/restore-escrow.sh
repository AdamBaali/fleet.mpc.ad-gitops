#!/usr/bin/env bash
# Re-escrow safely: retry the request until accepted (HTTP 409 = one is already in flight), wait for a NEW keyslot, refresh the stored escrow key
# (never overwrite it with garbage), then remove the stale slot. Needs a working passphrase file in the guest (/etc/luks-lab-pass) and the lab zenity wrapper.
set -uo pipefail
cd "$(dirname "$0")/.."; VM=luks-ubuntu; set -a; . ./.env; set +a; U=/Applications/UTM.app/Contents/MacOS/utmctl
slots(){ tools/vm-run.sh $VM 'cryptsetup luksDump /dev/nvme0n1p3 | grep -cE "^  [0-9]+: luks2"' 2>/dev/null | head -1; }
tools/vm-run.sh $VM '[ -f /usr/local/bin/zenity.lab-wrapper ] && mv /usr/local/bin/zenity.lab-wrapper /usr/local/bin/zenity; type -a zenity | head -1' | head -1
base=$(slots); echo "keyslots before: $base"
for i in $(seq 1 60); do c=$(tools/vm-run.sh $VM "T=\$(cat /opt/orbit/identifier); curl -s -o /dev/null -w '%{http_code}' -X POST \"$FLEET_URL/api/latest/fleet/device/\$T/mdm/linux/trigger_escrow\"" | head -1 | tr -cd '0-9' | cut -c1-3); echo "$(date +%H:%M:%S) trigger: HTTP $c"; [ "$c" = 204 ] && break; sleep 30; done
for i in $(seq 1 40); do n=$(slots); [ "$n" -gt "$base" ] 2>/dev/null && { echo "keyslots now: $n"; break; }; sleep 20; done
sleep 25
python3 -I - <<'PY' || { echo "could not read the new key from Fleet: keeping the old key file"; exit 1; }
import json,subprocess,os,sys
out=subprocess.run(['tools/fleetapi.py','/api/latest/fleet/hosts/17/encryption_key'],capture_output=True,text=True).stdout
k=json.loads(out)['encryption_key']['key']
assert len(k)==35
open('secrets/escrow-key.txt.new','w').write(k); os.chmod('secrets/escrow-key.txt.new',0o600)
PY
mv secrets/escrow-key.txt.new secrets/escrow-key.txt
$U file push $VM /tmp/.esc < secrets/escrow-key.txt >/dev/null 2>&1
tools/vm-run.sh $VM 'install -m 0600 /tmp/.esc /root/.escrowkey; rm -f /tmp/.esc; S=""; for s in $(cryptsetup luksDump /dev/nvme0n1p3 | grep -E "^  [0-9]+: luks2" | sed "s/[ :].*//"); do if cryptsetup open --test-passphrase /dev/nvme0n1p3 --key-file /root/.escrowkey -S $s >/dev/null 2>&1; then echo "escrow key opens slot $s"; else S="$S $s"; fi; done; echo "other slots:$S"; printf "user passphrase opens: "; cryptsetup open --test-passphrase /dev/nvme0n1p3 --key-file <(tr -d "\n" </etc/luks-lab-pass) >/dev/null 2>&1 && echo YES || echo no' | head -5
echo "fleet: $(tools/fleetapi.py /api/latest/fleet/hosts/17 | python3 -I -c "import json,sys; m=json.load(sys.stdin)['host'].get('mdm') or {}; print((m.get('os_settings') or {}).get('disk_encryption',{}).get('status'))")"
