#!/usr/bin/env bash
# G test: capture the REAL Fleet Desktop "Create key" banner state and the REAL passphrase dialog (zenity) on the guest's screen.
# Needs the VM up and unlocked (run after tests/run-all.sh). Never types the passphrase: the dialog is left to time out, then escrow is restored with the lab wrapper.
set -uo pipefail
cd "$(dirname "$0")/.."; VM=luks-ubuntu; D=test-evidence/ubuntu/G-banner-and-dialog; mkdir -p $D; set -a; . ./.env; set +a
step(){ echo; echo "=== $(date +%H:%M:%S) $*"; }
step "state: add a temporary slot with the escrow key, then remove Fleet's slot so Fleet shows 'action required'"
{ tools/vm-run.sh $VM 'printf tmp-%s "$RANDOM$RANDOM" > /root/.tmpk; cryptsetup luksAddKey /dev/nvme0n1p3 /root/.tmpk --key-file /root/.escrowkey && echo "temp slot added"; S=$(cryptsetup luksDump /dev/nvme0n1p3 | grep -E "^  [0-9]+: luks2" | sed "s/[ :].*//" | tr "\n" " "); echo "slots: $S"; cryptsetup luksKillSlot /dev/nvme0n1p3 1 --key-file /root/.tmpk && echo "Fleet slot 1 removed"; cryptsetup luksDump /dev/nvme0n1p3 | grep -E "^  [0-9]+: luks2" | tr "\n" " "; echo'; } > $D/00-state-setup.txt 2>&1; cat $D/00-state-setup.txt | tail -4
TOK=$(python3 -I -c "import re,os;print(re.search(r'token:\s*(\S+)',open(os.path.expanduser('~/.fleet/config')).read()).group(1))"); curl -s -o /dev/null -X POST -H "Authorization: Bearer $TOK" "$FLEET_URL/api/latest/fleet/hosts/17/refetch"; unset TOK
for i in $(seq 1 20); do st=$(tools/fleetapi.py /api/latest/fleet/hosts/17 | python3 -I -c "import json,sys; m=json.load(sys.stdin)['host'].get('mdm') or {}; print((m.get('os_settings') or {}).get('disk_encryption',{}).get('status'))"); echo "$(date +%H:%M:%S) fleet: $st"; [ "$st" = action_required ] && break; sleep 30; done | tee $D/01-fleet-status.txt | tail -2
step "banner: the My device page shows the 'Create key' banner (captured by the assistant with the browser, viewport only, no address bar)"
tools/vm-run.sh $VM 'cat /opt/orbit/identifier' > /tmp/devtok.txt 2>/dev/null; DT=$(grep -v '^\[exit' /tmp/devtok.txt | tr -d '\n '); rm -f /tmp/devtok.txt; echo "$FLEET_URL/device/$DT" > secrets/my-device-url.txt; chmod 600 secrets/my-device-url.txt; unset DT; echo "my device page URL saved to secrets/my-device-url.txt (contains a token, not printed)"
step "dialog: use the REAL zenity (take the lab wrapper away), request escrow, screenshot the guest screen until the dialog shows"
tools/vm-run.sh $VM 'mv /usr/local/bin/zenity /usr/local/bin/zenity.lab-wrapper; type -a zenity | head -1' | head -1
tools/vm-run.sh $VM "T=\$(cat /opt/orbit/identifier); curl -s -o /dev/null -w 'trigger_escrow: HTTP %{http_code}\n' -X POST \"$FLEET_URL/api/latest/fleet/device/\$T/mdm/linux/trigger_escrow\"" | head -1 | tee $D/02-trigger.txt
for i in $(seq 1 30); do tools/utm-vm.sh $VM shot $D/shot-$(printf %02d $i).png >/dev/null 2>&1; echo "guest screen $i/30 $(date +%H:%M:%S)"; sleep 15; done > $D/03-screens.log
echo "review the shots: keep the ones that show the dialog, delete the rest"
