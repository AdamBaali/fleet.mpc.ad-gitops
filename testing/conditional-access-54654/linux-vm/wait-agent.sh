#!/bin/bash
# Poll until the guest agent answers (cloud-init has installed qemu-guest-agent), up to 40 minutes.
U=/Applications/UTM.app/Contents/MacOS/utmctl
for i in $(seq 1 240); do
  out=$($U ip-address lab-linux 2>&1)
  if echo "$out" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then echo "AGENT UP after ~$((i*10))s"; echo "$out"; exit 0; fi
  sleep 10
done
echo "TIMEOUT waiting for guest agent"; $U status lab-linux; exit 1
