#!/bin/bash
# Inside the guest. K-13: after the end user's key is removed, can anyone decrypt and MOUNT the disk without IT's key? Scratch encrypted disk (never the root device).
F=/root/k13.img; truncate -s 96M $F; L=$(losetup -f --show $F); printf 'user-key-k13' > /root/.k13u; printf 'escrow-key-k13' > /root/.k13e
A="--pbkdf pbkdf2 --pbkdf-force-iterations 1000"
cryptsetup luksFormat --batch-mode --type luks2 $A $L /root/.k13u; cryptsetup luksAddKey $A $L /root/.k13e --key-file /root/.k13u
cryptsetup open $L k13 --key-file /root/.k13u; mkfs.ext4 -q /dev/mapper/k13; mkdir -p /mnt/k13; mount /dev/mapper/k13 /mnt/k13; echo "secret customer data" > /mnt/k13/data.txt; sync
echo "marker sha before: $(sha256sum /mnt/k13/data.txt | cut -c1-16)"; umount /mnt/k13; cryptsetup close k13
echo "== IT removes the end user's key with the escrow key"; cryptsetup luksKillSlot $L 0 --key-file /root/.k13e && echo "slot 0 (user) removed"; cryptsetup luksDump $L | grep -E "^  [0-9]+: luks2" | tr '\n' ' '; echo
echo "== someone with the disk and the user's old passphrase tries to decrypt and mount"
cryptsetup open $L k13b --key-file /root/.k13u 2>&1 | tail -1; ls /dev/mapper/k13b 2>&1 | tail -1
echo "== someone with the disk but no key, or the raw device: try to mount it directly"
mkdir -p /mnt/k13raw; mount $L /mnt/k13raw 2>&1 | tail -1; blkid $L | sed -E 's/UUID="[^"]*"/UUID="..."/'
echo "== IT with the escrow key"; cryptsetup open $L k13c --key-file /root/.k13e && mount /dev/mapper/k13c /mnt/k13 && echo "mounted; marker sha after: $(sha256sum /mnt/k13/data.txt | cut -c1-16)"; umount /mnt/k13; cryptsetup close k13c
echo "== does the raw disk contain the data in clear? (search the image file for the text)"; grep -c "secret customer data" $F | sed 's/^/occurrences of the plain text in the encrypted image: /'
losetup -d $L; rm -f $F /root/.k13u /root/.k13e; rmdir /mnt/k13 /mnt/k13raw 2>/dev/null; echo end
