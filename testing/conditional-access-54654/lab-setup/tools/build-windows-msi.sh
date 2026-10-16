#!/bin/bash
# Builds the fleetd MSI for the Ping Duo Lab fleet (x64 or arm64) into out/. The enroll secret is never printed.
# Usage: tools/build-windows-msi.sh [amd64|arm64]
cd "$(dirname "$0")/.." || exit 1
set -a; . ./.env; set +a
ARCH="${1:-amd64}"; mkdir -p out
( cd out && fleetctl package --type=msi --arch="$ARCH" --fleet-url="$FLEET_URL" --enroll-secret="$FLEET_PING_DUO_LAB_ENROLL_SECRET" \
  --fleet-desktop --enable-scripts --disable-open-folder 2>&1 | grep -v -i secret | tail -4 )
ls -la out/*.msi 2>/dev/null
