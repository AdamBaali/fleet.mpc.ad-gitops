#!/usr/bin/env bash
# Cold-restart a UTM VM that has an installer ISO still attached: stop, start, then pick "Boot from next volume" in GRUB (two Down, Return).
# There are TWO GRUB menus: the attached ISO's, then the installed system's. A typed passphrase must not arrive while either is showing (a "c" opens the GRUB command line).
# usage: tools/boot-vm.sh <vm>
VM="$1"; U=/Applications/UTM.app/Contents/MacOS/utmctl
$U stop "$VM" --force >/dev/null 2>&1; sleep 4; $U start "$VM"; sleep 9
sc(){ osascript -e "tell application \"UTM\" to input scan code (get virtual machine named \"$VM\") codes {$1}" >/dev/null 2>&1; }
sc "80, 208"; sleep 1; sc "80, 208"; sleep 1; sc "28, 156"; sleep 9; sc "28, 156"   # 2nd menu: the installed system's own GRUB (counts down ~30 s): Return picks Ubuntu now so nothing typed later lands in GRUB
echo "boot requested for $VM at $(date +%H:%M:%S)"
