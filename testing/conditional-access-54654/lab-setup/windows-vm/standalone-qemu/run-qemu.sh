#!/bin/bash
# Run the pingduo-win disk in standalone Homebrew QEMU (outside UTM) with Homebrew swtpm 0.10 (working ECC keys).
# Why: UTM's bundled swtpm cannot create ECC keys, and UTM's sandbox cannot reach an external swtpm socket.
# Network is user-mode (slirp): the Mac is 10.0.2.2 from the guest, so ping.lab must point to 10.0.2.2 in the guest hosts file.
# Control: QMP vm/winarm/run/qmp.sock, guest agent vm/winarm/run/qga.sock (see qmp.py, qga-cmd.py).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"; R="$H/run"; mkdir -p "$R/tpm"
DISK="${DISK:-<path to the VM's qcow2 disk>}"
[ -f "$R/vars.fd" ] || cp /opt/homebrew/share/qemu/edk2-arm-vars.fd "$R/vars.fd"
pgrep -f "swtpm socket --tpmstate dir=$R/tpm" >/dev/null || \
  swtpm socket --tpmstate dir="$R/tpm" --ctrl type=unixio,path="$R/swtpm.sock" --tpm2 --daemon --log file="$R/swtpm.log"
for i in $(seq 1 50); do [ -S "$R/swtpm.sock" ] && break; sleep 0.1; done
exec qemu-system-aarch64 -name pingduo-win -machine virt -accel hvf -cpu host -smp 4 -m 6144 \
  -uuid FD68384B-FE3E-400D-9EE3-8CCC4A40BDD4 \
  -drive if=pflash,format=raw,readonly=on,file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file="$R/vars.fd" \
  -drive file="$DISK",if=none,id=d0 -device nvme,drive=d0,serial=lab0,bootindex=0 \
  -chardev socket,id=chrtpm,path="$R/swtpm.sock" -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis-device,tpmdev=tpm0,ppi=off \
  -device ramfb -device qemu-xhci -device usb-kbd -device usb-tablet \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -device virtio-serial -chardev socket,id=qga0,path="$R/qga.sock",server=on,wait=off -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -qmp unix:"$R/qmp.sock",server,nowait -display cocoa
