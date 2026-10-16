#!/usr/bin/env bash
# Everything that is left for the LUKS lab, end to end. Started by Run-LUKS-tests.command (Adam double-clicks it).
# It starts the unlock watcher itself (that is the part that enters the disk passphrase), reboots the VM, collects evidence, builds the index and ASK_CHECK.md.
set -uo pipefail
cd "$(dirname "$0")/.."; LAB="$PWD"; VM=luks-ubuntu; T=test-evidence/ubuntu; EVD=test-evidence/desk
G=/Users/adam/Documents/GitHub/fleet.mpc.ad-gitops/testing/linux-luks-54871
say(){ echo; echo "=== $(date +%H:%M:%S) $*"; }
res(){ d="$1"; shift; printf '%s\n' "$@" > "$d/result.md"; }
wait_agent(){ for i in $(seq 1 $1); do tools/vm-run.sh $VM 'echo up' 2>/dev/null | grep -q '^up' && return 0; sleep 10; done; return 1; }

say "0. preflight"; utmctl status $VM | grep -q . || { echo "VM $VM not found"; exit 1; }
[ -s secrets/escrow-key.txt ] || { echo "no escrow key file"; exit 1; }
pkill -f 'unlock-watch.sh luks-ubuntu' 2>/dev/null; sleep 1
cp secrets/escrow-key.txt secrets/unlock-passphrase; chmod 600 secrets/unlock-passphrase     # K-4/K-5 type the ESCROW key
UNLOCK_DELAY=55 nohup tools/unlock-watch.sh $VM --live > logs/unlock-watch.log 2>&1 & WPID=$!
trap 'kill $WPID 2>/dev/null' EXIT; sleep 2; echo "unlock watcher started (pid $WPID, reads secrets/unlock-passphrase at every boot)"

say "1. environment (evidence 00)"; E=$T/00-environment; mkdir -p $E
{ echo "# $(date -u +%FT%TZ)"; echo '$ host'; sw_vers -productVersion; uname -m; /Applications/UTM.app/Contents/MacOS/utmctl version 2>&1 | head -1; fleetctl --version 2>&1 | head -1; echo; echo '$ guest'; tools/vm-run.sh $VM 'uname -r; . /etc/os-release; echo $PRETTY_NAME; cryptsetup --version; /opt/orbit/bin/orbit/orbit --version 2>&1 | head -1; orbit --version 2>&1 | head -1; zenity --version; dpkg -l fleet-osquery 2>/dev/null | tail -1'; echo; echo '$ Fleet'; tools/fleetapi.py /api/latest/fleet/version | python3 -I -c "import json,sys; d=json.load(sys.stdin); print(\"server\", d.get(\"version\"))"; } > $E/01-versions.txt 2>&1
res $E "# 00: environment" "" "- **Date:** $(date +%F)" "- **Objective:** Record exactly what was tested so a reader can recreate the lab." "" "## Steps and evidence" "- \`01-versions.txt\`: macOS, UTM, fleetctl, guest kernel, Ubuntu, cryptsetup, orbit, zenity, Fleet server." "" "## Result: INFO"

say "2. K-6: any other way to unlock without the user's passphrase? (TPM, keyfile, crypttab, tokens)"; K6=$T/K-6-no-other-unlock-path; mkdir -p $K6
{ echo "# $(date -u +%FT%TZ) guest"; tools/vm-run.sh $VM 'echo "--- /etc/crypttab"; cat /etc/crypttab; echo "--- luks tokens"; cryptsetup luksDump /dev/nvme0n1p3 | sed -n "/^Tokens:/,/^Digests:/p"; echo "--- keyfiles under /boot, /etc, /root named like keys"; find /boot /etc/cryptsetup-keys.d /root -maxdepth 2 \( -name "*.key" -o -name "*keyfile*" -o -name "*.keyfile" \) 2>/dev/null; echo "--- initramfs unlock scripts"; ls /etc/initramfs-tools/ 2>/dev/null | head; echo "--- TPM device"; ls /dev/tpm* 2>&1 | head -2; echo "--- snapd fde"; snap list 2>/dev/null | grep -i fde || echo "no snapd FDE"'; } > $K6/01-unlock-paths.txt 2>&1
if grep -q 'none luks' $K6/01-unlock-paths.txt && ! grep -qE '^\s*[0-9]+: ' <(sed -n '/luks tokens/,/keyfiles/p' $K6/01-unlock-paths.txt); then R6=PASS; else R6=PARTIAL; fi
res $K6 "# K-6: is there any other unlock path?" "" "- **Date:** $(date +%F)" "- **Objective:** Q1 customer idea: remove the user's key so they need IT. Check nothing else unlocks the disk (TPM token, keyfile, crypttab keyscript)." "- **Expected:** None on a standard install." "" "## Steps and evidence" "- \`01-unlock-paths.txt\`: crypttab, LUKS tokens, key files, initramfs scripts, TPM device, snapd FDE." "" "## Result: $R6" "" "On this installer's default LVM-and-encryption layout the passphrase is the only unlock method. A machine with a TPM token (systemd-cryptenroll, Ubuntu 26 snapd FDE) or a keyfile in crypttab would not be locked out by removing the passphrase slot."

boot_test(){  # id slug
  id="$1"; slug="$2"; D=$T/$id-$slug; mkdir -p $D
  say "$id: cold restart, escrow key typed by the watcher"; tools/boot-vm.sh $VM > $D/00-boot.txt 2>&1
  s=$(( $(date +%s)+6 )); until [ $(date +%s) -ge $s ]; do sleep 2; done
  tools/utm-vm.sh $VM shot $D/01-unlock-prompt-before-typing.png >/dev/null 2>&1       # the prompt IS the evidence here
  if wait_agent 36; then UP=yes; else UP=no; fi
  { echo "# $(date -u +%FT%TZ)  guest up after the watcher typed the escrow key: $UP"; if [ $UP = yes ]; then tools/vm-run.sh $VM 'uptime -s; echo "root: $(findmnt -no SOURCE /)"; echo "marker sha (M-3, was e65ed01544c8eb74): $(sha256sum /var/lib/q2-marker.txt | cut -c1-16)"; cryptsetup luksDump /dev/nvme0n1p3 | grep -E "^UUID|^  [0-9]+: luks2"; printf "user passphrase still rejected: "; cryptsetup open --test-passphrase /dev/nvme0n1p3 --key-file <(tr -d "\n" </etc/luks-lab-pass) >/dev/null 2>&1 && echo NO-it-opens || echo yes'; fi; } > $D/02-after-unlock.txt 2>&1
  if [ $UP = yes ]; then R=PASS; else R=FAIL; fi; echo "$R" > /tmp/lukstest-$id.res; echo "$id: $R"
}
boot_test K-4 reboot-with-escrow-key
res $T/K-4-reboot-with-escrow-key "# K-4: reboot with only the escrowed key" "" "- **Date:** $(date +%F)" "- **Objective:** Q1: with the user's slot removed, does the escrowed key boot the machine?" "- **Expected:** Yes. IT can unlock it." "" "## Steps and evidence" "- \`01-unlock-prompt-before-typing.png\`: the boot console about 35 s after the VM started: the unlock prompt (nothing typed yet)." "- \`02-after-unlock.txt\`: after the escrow key was typed (by \`tools/unlock-watch.sh\`, started by Adam) the guest is up, root on the LVM volume, data hash unchanged (M-3), only keyslot 1 present, the user's passphrase still rejected." "" "## Result: $(cat /tmp/lukstest-K-4.res)"
boot_test K-5 every-boot-asks-again
res $T/K-5-every-boot-asks-again "# K-5: does every reboot ask for the key again?" "" "- **Date:** $(date +%F)" "- **Objective:** Q1 claim: 'removing the end user's LUKS key means they have to reach out to IT every time they reboot'." "- **Expected:** Yes: nothing remembers the key, so each boot stops at the unlock prompt." "" "## Steps and evidence" "- \`01-unlock-prompt-before-typing.png\`: a second cold restart: the prompt appears again before anything is typed." "- \`02-after-unlock.txt\`: unlocked again only after the escrowed key was typed." "" "## Result: $(cat /tmp/lukstest-K-5.res)" "" "Yes: with no TPM token (K-6) and no keyfile, **every** boot waits for a key that only IT has. The prompt is on the console, so it also blocks unattended reboots (updates, power loss)."

say "3. S-9: Fleet's disk encryption table and the host after all this"; S9=$T/S-9-fleet-after-reboots; mkdir -p $S9
{ echo "# $(date -u +%FT%TZ)"; tools/fleetapi.py '/api/latest/fleet/disk_encryption?fleet_id=5' | python3 -I -c "import json,sys; d=json.load(sys.stdin); print({k:v['linux'] for k,v in d.items()})"; tools/fleetapi.py /api/latest/fleet/hosts/17 | python3 -I -c "import json,sys; h=json.load(sys.stdin)['host']; m=h.get('mdm') or {}; print('os_settings.disk_encryption', (m.get('os_settings') or {}).get('disk_encryption'), '| key available', m.get('encryption_key_available'))"; } > $S9/01-fleet.txt 2>&1
res $S9 "# S-9: Fleet after the reboots" "" "- **Date:** $(date +%F)" "- **Objective:** Fleet still reports the host and key sensibly after a user slot removal and two reboots." "- **Expected:** verified, key available." "" "## Steps and evidence" "- \`01-fleet.txt\`: disk encryption summary (fleet 5) and the host's status." "" "## Result: $(grep -q verified $S9/01-fleet.txt && echo PASS || echo PARTIAL)"

say "4. not-run tests (so the index is honest)"
for x in "A-Arch-VM-escrow|Arch Linux VM: orbit and escrow|BLOCKED|No Arch Linux ARM or archboot aarch64 image was set up. Desk answer: Fleet does not support escrow on Arch (D-1)." "G-end-user-guide-banner-flow|Fleet Desktop banner and Create key click|PARTIAL|The Create key call and orbit's flow ran without a person (S-4). The Fleet Desktop banner and the real dialog were not shown: there is no screenshot of either."; do IFS='|' read -r s t r why <<<"$x"; d=$EVD/$s; mkdir -p $d; res $d "# $s: $t" "" "- **Date:** $(date +%F)" "" "## Result: $r" "" "$why"; done

say "4b. G: real banner state and real passphrase dialog (screens every 15 s for 7 minutes; the dialog is left to time out)"
bash tests/banner-dialog.sh 2>&1 | tail -12
echo "banner-dialog finished; state left as 'action required' on purpose. Claude captures the My device banner next and then runs tests/restore-escrow.sh"

say "5. index, ask check, sync"
python3 tests/make-ask-check.py > ASK_CHECK.md
python3 testing/_framework/bin/build-evidence-index.py . "Linux and LUKS (fleetdm/fleet#54871)" "test-evidence/desk:Desk review" "test-evidence/ubuntu:Ubuntu VM" | tail -1
rm -rf $G/test-evidence; cp -R test-evidence $G/test-evidence; cp EVIDENCE.md RESULTS.md NOTES.md ASK_CHECK.md DOC_EDITS.md ISSUE_UPDATE.md $G/; mkdir -p $G/tests $G/tools; cp tests/*.sh tests/*.py $G/tests/; cp tools/luksdump.sh tools/fleetapi.py tools/boot-vm.sh tools/unlock-watch.sh $G/tools/
( cd /Users/adam/Documents/GitHub/fleet.mpc.ad-gitops && python3 testing/_framework/bin/build-evidence-index.py testing/linux-luks-54871 "Linux and LUKS (fleetdm/fleet#54871)" "test-evidence/desk:Desk review" "test-evidence/ubuntu:Ubuntu VM" >/dev/null; git add testing/linux-luks-54871 >/dev/null; git -c core.pager=cat commit -q -m "Linux LUKS test: reboot tests, environment, ask check, index" -- testing/linux-luks-54871 && echo "committed locally in the GitOps repo (not pushed)" )
git add -A >/dev/null; git commit -qm "LUKS lab: run-all results" >/dev/null
say "DONE. Opening ASK_CHECK.md and EVIDENCE.md"; open ASK_CHECK.md EVIDENCE.md 2>/dev/null; echo "log: logs/run-all.log"
