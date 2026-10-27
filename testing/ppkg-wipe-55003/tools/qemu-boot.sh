#!/bin/bash
# Boot a Windows arm64 disk under Homebrew QEMU and edk2, without UTM.
# Usage: tools/qemu-boot.sh <name> <base.qcow2> [fresh|<efi_vars.fd>]
#
# UTM 4.7.5 hangs at "Start boot option" on the first boot after a reset or generalize.
# This runs the same disk on a newer QEMU and edk2 to tell a UTM fault from a Windows one.
# The base disk stays untouched: QEMU writes to an overlay in out/qemu/<name>/.
# Control is headless: QMP socket for screendumps and keys, the guest agent socket for commands
# (tools/qga.sh), and VNC on localhost for a person.
set -euo pipefail
name=$1 base=$2 vars=${3:-fresh}
here=$(cd "$(dirname "$0")/.." && pwd)
dir=$here/out/qemu/$name
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

# Two displays. ramfb under HVF shows stale screens once full Windows is up (only some areas refresh, likely cache
# coherency on Apple silicon), so Windows uses virtio-gpu through viogpudo from UTM guest tools. The reset
# environment (WinRE) has no viogpudo and draws on ramfb. tools/qmp.sh shot picks the live one.
# USB=<image> attaches a read-only USB disk. Windows sees it as fixed, as v1 did in UTM, so setup doesn't apply the
# package by itself; it's opened from Shift+F10. USB_REMOVABLE=on makes setup apply it, which in this lab ends in
# Provisioning failure 0x800700b7 (C-1, C-2).
usb=()
[ -n "${USB:-}" ] && usb=(-drive if=none,id=usb0,format=raw,readonly=on,file="$USB" -device usb-storage,drive=usb0,removable=${USB_REMOVABLE:-off})

exec qemu-system-aarch64 -name "$name" \
  -smbios type=1,uuid="$uuid",serial="${SERIAL:-$name}" \
  -machine virt,highmem=on -accel hvf -cpu host -smp 4 -m 6144 \
  -drive if=pflash,format=raw,readonly=on,file=$share/edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file="$dir/vars.fd" \
  -device nvme,drive=d0,serial=${SERIAL:-$name} -drive if=none,id=d0,file="$dir/disk.qcow2" \
  -device ramfb,id=fb -device virtio-gpu-pci,id=gpu -device qemu-xhci -device usb-kbd -device usb-tablet \
  -nic user,model=virtio-net-pci,mac="$mac" \
  ${tpm[@]+"${tpm[@]}"} ${usb[@]+"${usb[@]}"} \
  -device virtio-serial-pci -chardev socket,id=qga0,path="$dir/qga.sock",server=on,wait=off \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -qmp unix:"$dir/qmp.sock",server,nowait -vnc 127.0.0.1:${VNC:-1} -display none \
  -serial file:"$dir/serial.log" -pidfile "$dir/pid" -daemonize
