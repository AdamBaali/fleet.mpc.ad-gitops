#!/bin/bash
# Install Windows 11 arm64 onto a new base disk under Homebrew QEMU, without UTM.
# Usage: FG=1 vm/qemu-install.sh <name> <base.qcow2> <windows.iso> <answer.iso>
#   then press a key within 5 s (qmp.sh <name> keys spc) so the firmware boots the CD.
# Installs in QEMU, not UTM: on macOS 27 Claude Code's processes can't open UTM's container
# (~/Library/Containers/com.utmapp.UTM), and Full Disk Access on Claude.app doesn't reach them.
# Same machine, display, and sockets as qemu-boot.sh, so qmp.sh and screen.sh work on it. CDs are USB CD-ROMs: edk2
# boots them and Windows setup reads them with inbox drivers. Attach only the Windows ISO and the answer ISO
# (vm/answer/, built with hdiutil makehybrid): UTM's guest tools ISO has its own Autounattend.xml, which setup could
# pick up instead.
set -euo pipefail
name=$1 base=$2; shift 2
root=${VM_ROOT:-$HOME/Documents/fleet-lab/vm}
dir=$root/$name
mkdir -p "$dir"
share=/opt/homebrew/share/qemu

[ -f "$base" ] || qemu-img create -q -f qcow2 "$base" 64G
[ -f "$dir/vars.fd" ] || truncate -s 64M "$dir/vars.fd"
[ -f "$dir/mac" ] || printf '52:54:00:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) > "$dir/mac"
[ -f "$dir/uuid" ] || uuidgen > "$dir/uuid"

cds=(); i=0
for iso in "$@"; do
  cds+=(-drive if=none,id=cd$i,media=cdrom,readonly=on,file="$iso" -device usb-storage,drive=cd$i)
  i=$((i+1))
done

exec qemu-system-aarch64 -name "$name" \
  -smbios type=1,uuid="$(cat "$dir/uuid")",serial="${SERIAL:-$name}" \
  -machine virt,highmem=on -accel hvf -cpu host -smp 4 -m 6144 \
  -drive if=pflash,format=raw,readonly=on,file=$share/edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file="$dir/vars.fd" \
  -device nvme,drive=d0,serial=${SERIAL:-$name} -drive if=none,id=d0,file="$base" \
  -device ramfb,id=fb -device qemu-xhci -device usb-kbd -device usb-tablet \
  -nic user,model=virtio-net-pci,mac="$(cat "$dir/mac")" \
  "${cds[@]}" \
  -device virtio-serial-pci -chardev socket,id=qga0,path="$dir/qga.sock",server=on,wait=off \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -qmp unix:"$dir/qmp.sock",server,nowait -vnc 127.0.0.1:${VNC:-2} -display none \
  -serial file:"$dir/serial.log" -pidfile "$dir/pid" $( [ -n "${FG:-}" ] || echo -daemonize )
