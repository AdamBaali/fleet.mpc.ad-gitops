#!/bin/bash
# Run a CLONE of bitlocker-lab's disk in standalone QEMU (patched build in vm/qemu/build), outside UTM.
# usage: vm/run-qemu-clone.sh <pm_profile>   0 = Unspecified (as QEMU/UTM), 8 = Tablet ("slate")
# Disk: vm/clone/disk.qcow2 (APFS clone of the UTM disk, 23:14; BitLocker protection was On, so the first boot needs the recovery key). Fresh TPM (swtpm) and UEFI vars.
# Network: restrict=on (no route out: the clone must not talk to Fleet as a second host 16).
# Control: QMP socket vm/clone/qmp.sock (screendump, send-key) via vm/qmp.py. Nothing here touches UTM or the UTM bundle.
set -eu
H="$(cd "$(dirname "$0")" && pwd)"; C="$H/clone"; Q="$H/qemu/build/qemu-system-aarch64"
PROFILE="${1:-0}"
mkdir -p "$C/tpm"
[ -f "$C/vars.fd" ] || cp /opt/homebrew/share/qemu/edk2-arm-vars.fd "$C/vars.fd"
pgrep -f "swtpm socket --tpmstate dir=$C/tpm" >/dev/null || \
  swtpm socket --tpmstate dir="$C/tpm" --ctrl type=unixio,path="$C/swtpm.sock" --tpm2 --daemon --log file="$C/swtpm.log"
for i in $(seq 1 50); do [ -S "$C/swtpm.sock" ] && break; sleep 0.1; done
export QEMU_FADT_PM_PROFILE="$PROFILE"
exec "$Q" -name "bitlocker-clone-pm$PROFILE" -machine virt -accel hvf -cpu host -smp 4 -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file="${FW:-/opt/homebrew/share/qemu/edk2-aarch64-code.fd}" \
  -drive if=pflash,format=raw,file="$C/vars.fd" \
  -drive file="$C/disk.qcow2",if=none,id=d0 -device nvme,drive=d0,serial=lab0 \
  -chardev socket,id=chrtpm,path="$C/swtpm.sock" -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis-device,tpmdev=tpm0,ppi=off \
  -device ramfb -device qemu-xhci -device usb-kbd -device usb-tablet \
  -netdev user,id=n0,restrict=${NET_RESTRICT:-on} -device virtio-net-pci,netdev=n0 \
  -device virtio-serial -chardev socket,id=qga0,path="$C/qga.sock",server=on,wait=off -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -qmp unix:"$C/qmp.sock",server,nowait -display cocoa
