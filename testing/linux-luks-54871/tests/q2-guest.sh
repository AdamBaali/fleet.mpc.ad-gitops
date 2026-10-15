#!/bin/bash
# Runs INSIDE the guest as root. Q2: do keyslot changes touch the master key? Prints only digests (shortened), UUID, slot lists and hashes. No secrets.
DEV=/dev/nvme0n1p3; USERP=/etc/luks-lab-pass; ESC=/root/.escrowkey; TMPK=/root/.tmpkey; NEWK=/root/.newkey
dig(){ cryptsetup luksDump $DEV | awk '/Digests:/{f=1} f&&/Digest:/{gsub(/[ \t]/,"",$0); print substr($0,8,16)"..."; exit}'; }
uuid(){ cryptsetup luksDump $DEV | awk '/^UUID:/{print $2}'; }
slots(){ cryptsetup luksDump $DEV | awk '/^Keyslots:/{f=1;next} /^Tokens:/{f=0} f&&/^  [0-9]+: luks2/{printf "%s ",$1} END{print ""}'; }
mark(){ sha256sum /var/lib/q2-marker.txt | cut -c1-16; }
state(){ echo "  uuid=$(uuid) digest=$(dig) slots=[$(slots)] marker_sha=$(mark)"; }
head -c 4096 /dev/urandom | base64 > /var/lib/q2-marker.txt; sync
echo "M-1 baseline"; state
printf 'tempkey-%s' "$RANDOM$RANDOM" > $TMPK; printf 'newkey-%s' "$RANDOM$RANDOM" > $NEWK; chmod 600 $TMPK $NEWK
echo "M-2a luksAddKey (authorised with the escrow key; adds slot 2)"; cryptsetup luksAddKey $DEV $TMPK --key-file $ESC; state
echo "M-2b luksChangeKey slot 2 (new passphrase)"; cryptsetup luksChangeKey $DEV $NEWK --key-file $TMPK --key-slot 2; state
echo "M-2c luksKillSlot 2 (removes it, authorised with the escrow key)"; cryptsetup luksKillSlot $DEV 2 --key-file $ESC; state
echo "M-2d luksAddKey again, then luksRemoveKey by passphrase"; cryptsetup luksAddKey $DEV $TMPK --key-file $ESC; state; cryptsetup luksRemoveKey $DEV $TMPK; state
echo "M-2e escrow key and user passphrase still open their slots"
cryptsetup open --test-passphrase $DEV --key-file $ESC -S 1 && echo "  escrow slot 1: opens"; cryptsetup open --test-passphrase $DEV --key-file <(tr -d '\n' <$USERP) -S 0 && echo "  user slot 0: opens"
echo "M-3 data still reads (no re-encryption): marker sha unchanged above; root fs mounted: $(findmnt -no SOURCE /)"
echo "M-5 control on a scratch loop device (never the root): which command DOES change the volume key"
F=/root/scratch.img; truncate -s 64M $F; L=$(losetup -f --show $F); P=/root/.scratchp; printf scratch-pass > $P
cryptsetup luksFormat --batch-mode --type luks2 --pbkdf pbkdf2 --pbkdf-force-iterations 1000 $L $P 2>&1 | tail -1
sd(){ cryptsetup luksDump $L | awk '/Digests:/{f=1} f&&/Digest:/{gsub(/[ \t]/,"",$0); print substr($0,8,16)"..."; exit}'; }
echo "  scratch digest before: $(sd)"
cryptsetup luksAddKey $L $TMPK --key-file $P --pbkdf pbkdf2 --pbkdf-force-iterations 1000 2>/dev/null || { printf x2 > $TMPK; cryptsetup luksAddKey $L $TMPK --key-file $P --pbkdf pbkdf2 --pbkdf-force-iterations 1000; }; echo "  after luksAddKey: $(sd)"
cryptsetup luksChangeKey $L $NEWK --key-file $P --pbkdf pbkdf2 --pbkdf-force-iterations 1000 2>/dev/null; echo "  after luksChangeKey: $(sd)"
cryptsetup reencrypt --batch-mode --key-file $P $L 2>&1 | tail -1; echo "  after cryptsetup reencrypt: $(sd)"
losetup -d $L; rm -f $F $P $TMPK $NEWK
echo "end"
