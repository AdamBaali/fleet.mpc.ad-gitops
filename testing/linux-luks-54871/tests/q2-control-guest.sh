#!/bin/bash
# Inside the guest. Control for M-5 on a scratch loop file (never the root device): only reencrypt / luksFormat change the volume key.
F=/root/scratch.img; truncate -s 64M $F; L=$(losetup -f --show $F); P=/root/.scratchp; printf scratch-pass > $P; printf second-pass > /root/.sp2
sd(){ cryptsetup luksDump $L | awk '/Digests:/{f=1} f&&/Digest:/{gsub(/[ \t]/,"",$0); print substr($0,8,16)"..."; exit}'; }
A="--pbkdf pbkdf2 --pbkdf-force-iterations 1000"
cryptsetup luksFormat --batch-mode --type luks2 $A $L $P; echo "digest after luksFormat:        $(sd)"
cryptsetup luksAddKey $A $L /root/.sp2 --key-file $P; echo "digest after luksAddKey:        $(sd)"
cryptsetup luksKillSlot $L 1 --key-file $P; echo "digest after luksKillSlot:      $(sd)"
cryptsetup reencrypt --batch-mode --key-file $P --key-slot 0 $A $L 2>&1 | tail -1; echo "digest after reencrypt:         $(sd)"
cryptsetup luksFormat --batch-mode --type luks2 $A $L $P; echo "digest after luksFormat again:  $(sd)"
losetup -d $L; rm -f $F $P /root/.sp2
