#!/bin/bash
# Boot a Windows arm64 disk under Homebrew QEMU and edk2, without UTM.
# Usage: qemu-boot.sh <name> <base.qcow2> [fresh|<efi_vars.fd>]
# FG=1 keeps QEMU in the foreground, for a long-lived background task that nothing else reaps.
#
# UTM 4.7.5 hangs at "Start boot option" on the first boot after a reset or generalize.
# This runs the same disk on a newer QEMU and edk2 to tell a UTM fault from a Windows one.
# The base disk stays untouched: QEMU writes to an overlay in $VM_ROOT/<name>/ (default out/qemu).
# Control is headless: QMP socket for screendumps and keys, the guest agent socket for commands
# (qga.sh), and VNC on localhost for a person.
set -euo pipefail
name=$1 base=$2 vars=${3:-fresh}
root=${VM_ROOT:-$PWD/out/qemu}
dir=$root/$name
mkdir -p "$dir/tpm"
share=/opt/homebrew/share/qemu

[ -f "$dir/disk.qcow2" ] || qemu-img create -q -f qcow2 -F qcow2 -b "$base" "$dir/disk.qcow2"
if [ ! -f "$dir/vars.fd" ]; then
  # "fresh" gives edk2 an empty NVRAM, so it boots \EFI\BOOT\BOOTAA64.EFI and ignores
  # any boot entries Windows wrote during specialize.
  if [ "$vars" = fresh ]; then truncate -s 64M "$dir/vars.fd"
  else qemu-img convert -O raw "$vars" "$dir/vars.fd"; fi
fi

# Upstream QEMU's arm TPM device fails under HVF (HV_BAD_ARGUMENT), so the TPM is opt-in.
# An installed Windows boots and resets without one.
tpm=()
if [ "${TPM:-0}" = 1 ]; then
  swtpm socket --tpm2 --tpmstate dir="$dir/tpm" --ctrl type=unixio,path="$dir/tpm.sock" --daemon
  tpm=(-chardev socket,id=chrtpm,path="$dir/tpm.sock" -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis-device,tpmdev=tpm0)
fi
[ -f "$dir/mac" ] && MAC=${MAC:-$(cat "$dir/mac")}
mac=${MAC:-$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))}
echo "$mac" > "$dir/mac"
# Fleet matches hosts on the SMBIOS UUID and serial, so each VM keeps its own across restarts and resets.
[ -f "$dir/uuid" ] || uuidgen > "$dir/uuid"
uuid=$(cat "$dir/uuid")

# Display: ramfb. It can show stale screens later in setup under HVF (only some areas refresh), but keystrokes
# still land. GPU=virtio adds virtio-gpu (viogpudo from UTM guest tools), which draws correctly, but with it
# present the first boot after sysprep generalize fails with 0xc0000001 and a reset hangs (ppkg-wipe-55003 C-2, C-2r), so use it
# only on a VM that won't reset.
# USB=<image> attaches a read-only USB disk. Windows sees it as fixed, as v1 did in UTM, so setup doesn't apply the
# package by itself; it's opened from Shift+F10. USB_REMOVABLE=on makes setup apply it, which in this lab ends in
# Provisioning failure 0x800700b7 (ppkg-wipe-55003 C-1, C-2).
usb=()
[ -n "${USB:-}" ] && usb=(-drive if=none,id=usb0,format=raw,readonly=on,file="$USB" -device usb-storage,drive=usb0,removable=${USB_REMOVABLE:-off})

exec qemu-system-aarch64 -name "$name" \
  -smbios type=1,uuid="$uuid",serial="${SERIAL:-$name}" \
  -machine virt,highmem=on -accel hvf -cpu host -smp 4 -m 6144 \
  -drive if=pflash,format=raw,readonly=on,file=$share/edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file="$dir/vars.fd" \
  -device nvme,drive=d0,serial=${SERIAL:-$name} -drive if=none,id=d0,file="$dir/disk.qcow2" \
  -device ramfb,id=fb $( [ "${GPU:-}" = virtio ] && echo -device virtio-gpu-pci,id=gpu ) -device qemu-xhci -device usb-kbd -device usb-tablet \
  -nic user,model=virtio-net-pci,mac="$mac" \
  ${tpm[@]+"${tpm[@]}"} ${usb[@]+"${usb[@]}"} \
  -device virtio-serial-pci -chardev socket,id=qga0,path="$dir/qga.sock",server=on,wait=off \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -qmp unix:"$dir/qmp.sock",server,nowait -vnc 127.0.0.1:${VNC:-1} -display none \
  -serial file:"$dir/serial.log" -pidfile "$dir/pid" $( [ -n "${FG:-}" ] || echo -daemonize )
