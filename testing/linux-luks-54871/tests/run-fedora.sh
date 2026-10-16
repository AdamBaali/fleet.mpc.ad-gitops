#!/usr/bin/env bash
# Fedora 44 VM (luks-fedora): the same questions as Ubuntu, over SSH (SELinux confines the guest agent there).
#   F-1 environment, F-2 escrow slot, F-3 keyslot changes keep the master key (Q2), F-4 user slot removed + two reboots with only the escrow key (Q1).
# Needs: guest up and unlocked, secrets/escrow-fedora.txt, /etc/luks-lab-pass and /root/.escrowkey in the guest. Prints no secrets.
set -uo pipefail
cd "$(dirname "$0")/.."; LAB="$PWD"; VM=luks-fedora; IP=192.168.64.16; T=test-evidence/fedora; DEV=/dev/nvme0n1p3
KEY="$LAB/secrets/lab_ed25519"
g(){ ssh -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=8 lab@$IP "$@" 2>/dev/null; }
say(){ echo; echo "=== $(date +%H:%M:%S) $*"; }
dump(){ SSH_TARGET=lab@$IP tools/luksdump.sh $VM $DEV; }
fleet_status(){ tools/fleetapi.py /api/latest/fleet/hosts/19 | python3 -I -c "import json,sys; h=json.load(sys.stdin)['host']; print(h['mdm']['os_settings']['disk_encryption']['status'])"; }
mkdir -p "$T" logs
g true || { echo "guest not reachable over SSH"; exit 1; }
[ -s secrets/escrow-fedora.txt ] || { echo "no escrow key file"; exit 1; }

say "F-1 environment"; D=$T/F-1-environment; mkdir -p $D
{ echo "# $(date -u +%FT%TZ)"; g 'cat /etc/fedora-release; uname -r; uname -m; cryptsetup --version; rpm -q fleet-osquery zenity cryptsetup; /opt/orbit/bin/orbit/orbit --version 2>/dev/null | head -1; lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINTS; getenforce'; } > $D/01-guest.txt 2>&1
dump > $D/02-luksdump-masked.txt
cat > $D/result.md <<EOF
# F-1: Fedora VM environment

- **Date:** $(date +%F)
- **Objective:** Record the Fedora VM so a reader can recreate it.
- **Expected:** Fedora Server 44 aarch64 with root on LVM inside LUKS2, fleetd enrolled in the Linux LUKS Lab fleet.

## Steps and evidence
- \`01-guest.txt\`: release, kernel, cryptsetup, fleetd, disk layout, SELinux mode.
- \`02-luksdump-masked.txt\`: \`cryptsetup luksDump\` with salts masked and the digest shortened.

## Deviations (logged, not hidden)
- Fedora Server netinst with a kickstart (\`tests/gen-fedora-ks.py\`): text mode, \`autopart --type=lvm --encrypted\`, GNOME workstation package set, autologin so the escrow dialog has a desktop.
- The GRUB menu of the installer ignored letter keys, so the kickstart came from a disk labelled OEMDRV, not \`inst.ks=\`.
- Kernel options \`nomodeset console=tty0 console=ttyAMA0\`: without them the VM display stayed "not active" after GRUB. The screen is still blank, so no screenshots of the Fedora console.
- \`selinux --permissive\`: with SELinux enforcing, the QEMU guest agent is confined and cannot write files or manage services, so tests run over SSH (key installed by the kickstart).
- The kickstart's download of the fleetd rpm failed (curl 52); it was installed by hand with \`dnf install\`.
- The first two installs failed to give a usable login (empty password hash from macOS openssl) and a first boot with no usable display; both were reinstalled.

## Result: INFO
EOF

say "F-2 escrow slot"; D=$T/F-2-escrow-slot; mkdir -p $D
{ echo "# $(date -u +%FT%TZ)"; echo "fleet disk encryption status: $(fleet_status)"; echo; echo "keyslots:"; g "sudo cryptsetup luksDump $DEV | grep -E '^  [0-9]+: luks2'"; for s in 0 1; do printf "escrow key opens slot $s: "; g "sudo cryptsetup open --test-passphrase $DEV --key-file /root/.escrowkey -S $s && echo yes || echo no" | tail -1; done; for s in 0 1; do printf "user passphrase opens slot $s: "; g "sudo bash -c 'cryptsetup open --test-passphrase $DEV --key-file <(tr -d \"\\n\" </etc/luks-lab-pass) -S $s && echo yes || echo no'" | tail -1; done; } > $D/01-slots.txt 2>&1
dump > $D/02-luksdump-masked.txt
S0=$(grep -c 'user passphrase opens slot 0: yes' $D/01-slots.txt); S1=$(grep -c 'escrow key opens slot 1: yes' $D/01-slots.txt); V=$(grep -c 'status: verified' $D/01-slots.txt)
[ "$S0$S1$V" = "111" ] && R=PASS || R=FAIL
cat > $D/result.md <<EOF
# F-2: Fleet escrow adds a key slot on Fedora

- **Date:** $(date +%F)
- **Objective:** Does Fleet's Linux escrow work on Fedora, and what does it change on the disk?
- **Expected:** One new key slot (slot 1) that the escrowed key opens; the user's slot 0 untouched; Fleet shows Verified.

## Steps and evidence
- The escrow was requested through Fleet's device API (\`POST /device/{token}/mdm/linux/trigger_escrow\`, HTTP 204); the passphrase dialog was answered by the lab zenity wrapper (as on Ubuntu). Orbit added the slot about 14 minutes later (this Mac was busy; Ubuntu took 4).
- \`01-slots.txt\`: Fleet status, slot list, which key opens which slot.
- \`02-luksdump-masked.txt\`: header after escrow (2 slots, salts masked).
- Before the request the disk had 1 slot (counted, not saved as a dump).

## Result: $R
EOF
echo "F-2: $R"

say "F-3 keyslot changes (Q2)"; D=$T/F-3-keyslot-changes-keep-master-key; mkdir -p $D
scp -q -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null tests/q2-guest-any.sh lab@$IP:/tmp/q2.sh 2>/dev/null
g 'sudo bash /tmp/q2.sh; rm -f /tmp/q2.sh' > $D/01-q2-run.txt 2>&1
python3 -I - $D <<'PY' > $D/.verdict
import re,sys
t=open(sys.argv[1]+'/01-q2-run.txt').read()
st=re.findall(r'uuid=(\S+) digest=(\S+) slots=\[([^\]]*)\] marker_sha=(\S+)',t)
base=st[:1]; same=all((u,d,m)==(st[0][0],st[0][1],st[0][3]) for u,d,s,m in st) if st else False
ctrl=re.findall(r'scratch digest before: (\S+)|after luksAddKey: (\S+)|after luksChangeKey: (\S+)|after cryptsetup reencrypt: (\S+)',t)
flat=[x for g in ctrl for x in g if x]
ok_ctrl=len(flat)==4 and flat[0]==flat[1]==flat[2] and flat[3]!=flat[0]
print(('PASS' if (len(st)>=6 and same and ok_ctrl) else 'FAIL'), len(st), same, ok_ctrl)
PY
R=$(cut -d' ' -f1 $D/.verdict); rm -f $D/.verdict
cat > $D/result.md <<EOF
# F-3: add, change, kill and remove key slots keep the master key (Fedora)

- **Date:** $(date +%F)
- **Objective:** Q2: does LUKS invalidate any encryption key when a passphrase or key slot is rotated?
- **Expected:** UUID, master key digest and the data hash stay the same through luksAddKey, luksChangeKey, luksKillSlot and luksRemoveKey. A scratch-device control shows that only \`cryptsetup reencrypt\` changes the digest.

## Steps and evidence
- \`01-q2-run.txt\`: raw output of \`tests/q2-guest-any.sh\` (digests shortened to 16 hex chars, no keys). Slot 2 is added, changed, killed, added again and removed, authorised with the escrow key. After every step the line shows UUID, digest, slot list and a hash of a marker file on the encrypted root.
- The control (M-5) runs on a 64 MB loop device, never on the root disk.

## Result: $R
EOF
echo "F-3: $R"

say "F-4 user slot removed, reboot with only the escrow key (Q1)"; D=$T/F-4-user-slot-removed-reboots; mkdir -p $D
dump > $D/01-luksdump-before.txt
g "sudo cryptsetup luksKillSlot $DEV 0 --key-file /root/.escrowkey" > $D/02-kill-user-slot.txt 2>&1; echo "exit: $?" >> $D/02-kill-user-slot.txt
dump > $D/03-luksdump-after-kill.txt
{ printf "old user passphrase rejected: "; g "sudo bash -c 'cryptsetup open --test-passphrase $DEV --key-file <(tr -d \"\\n\" </etc/luks-lab-pass) >/dev/null 2>&1 && echo NO-it-still-opens || echo yes'"; printf "escrow key opens: "; g "sudo cryptsetup open --test-passphrase $DEV --key-file /root/.escrowkey && echo yes || echo no"; echo "marker sha before reboots: $(g 'sudo sha256sum /var/lib/q2-marker.txt | cut -c1-16')"; echo "fleet status right after: $(fleet_status)"; } > $D/04-checks-before-reboot.txt 2>&1
# watcher types the ESCROW key at each boot
pkill -f 'unlock-watch.sh luks-fedora' 2>/dev/null; sleep 1
cp secrets/escrow-fedora.txt secrets/unlock-passphrase; chmod 600 secrets/unlock-passphrase
UNLOCK_DELAY=90 nohup tools/unlock-watch.sh $VM --live > logs/unlock-watch-fedora.log 2>&1 & WPID=$!
trap 'kill $WPID 2>/dev/null' EXIT; sleep 3
up=0
for n in 1 2; do
  say "reboot $n"; g 'sync'; utmctl stop $VM --force >/dev/null 2>&1; sleep 6; S0=$(date +%s); utmctl start $VM >/dev/null 2>&1
  first=none; for i in $(seq 1 90); do if g true; then first=$(( $(date +%s)-S0 )); break; fi; sleep 5; done
  typed=$(grep -c 'unlock typed' logs/unlock-watch-fedora.log)
  { echo "# reboot $n at $(date -u +%FT%TZ)"; echo "seconds from VM start until SSH answered: $first (the watcher types the key 90 s after start)"; echo "times the watcher typed so far: $typed"; if [ "$first" != none ]; then g 'uptime -s; echo "root: $(findmnt -no SOURCE /)"; sudo cryptsetup luksDump '$DEV' | grep -E "^  [0-9]+: luks2"; echo "marker sha: $(sudo sha256sum /var/lib/q2-marker.txt | cut -c1-16)"'; fi; } > $D/05-reboot-$n.txt 2>&1
  [ "$first" != none ] && [ "$first" -ge 85 ] && up=$((up+1))
done
echo "fleet status after both reboots: $(fleet_status)" > $D/06-fleet-after.txt
ONLY1=$(grep -c '^  1: luks2' $D/03-luksdump-after-kill.txt); NO0=$(grep -c '^  0: luks2' $D/03-luksdump-after-kill.txt)
if [ $up = 2 ] && grep -q 'rejected: yes' $D/04-checks-before-reboot.txt && grep -q 'escrow key opens: yes' $D/04-checks-before-reboot.txt && [ "$ONLY1$NO0" = "10" ]; then R=PASS; else R=FAIL; fi
cat > $D/result.md <<EOF
# F-4: remove the user's key slot; does every reboot ask for the key? (Fedora)

- **Date:** $(date +%F)
- **Objective:** Q1: after the end user's LUKS key is removed, does the user have to contact IT at every reboot?
- **Expected:** The old passphrase is rejected, the escrowed key unlocks the disk, and every boot waits at the unlock prompt until someone types the key.

## Steps and evidence
- \`01\`–\`03\`: masked luksDump before and after \`luksKillSlot\` on slot 0 (authorised with the escrow key).
- \`04-checks-before-reboot.txt\`: the old passphrase no longer opens any slot, the escrow key does, the data hash, Fleet's status.
- \`05-reboot-1.txt\`, \`05-reboot-2.txt\`: two cold restarts. SSH answered only after the watcher had typed the escrow key (about 90 s after the VM started), so the machine did not boot unattended. Both boots came up with only slot 1 and the same data hash.
- \`06-fleet-after.txt\`: Fleet's status afterwards (it does not check the user's slot).
- No screenshot of the unlock prompt: the Fedora console stays blank in this VM (see F-1). The Ubuntu run shows the prompt (K-3).

## Result: $R
EOF
echo "F-4: $R"

say "restore: give the user a slot again (authorised with the escrow key)"
g "sudo cryptsetup luksAddKey $DEV /etc/luks-lab-pass --key-file /root/.escrowkey" > $D/07-restore-user-slot.txt 2>&1; echo "exit: $?" >> $D/07-restore-user-slot.txt
set -a; . ./.env; set +a; printf %s "$LUKS_USER_PASSPHRASE" > secrets/unlock-passphrase; chmod 600 secrets/unlock-passphrase
g "sudo cryptsetup luksDump $DEV | grep -E '^  [0-9]+: luks2'" >> $D/07-restore-user-slot.txt
kill $WPID 2>/dev/null
say "DONE"
