#!/bin/bash
# Builds the fleetd MSI (arm64 by default) for the "Windows BitLocker Lab" fleet into out/. Needs Docker running.
# The enroll secret is read from .env and never printed. Usage: [NO_DESKTOP=1] tools/build-windows-msi.sh [arm64|amd64]
# NO_DESKTOP=1 builds without Fleet Desktop (like the customer) into out/no-desktop/.
cd "$(dirname "$0")/.." || exit 1
set -a; . ./.env; set +a
[ -n "$FLEET_WINDOWS_BITLOCKER_LAB_ENROLL_SECRET" ] || { echo "FLEET_WINDOWS_BITLOCKER_LAB_ENROLL_SECRET missing in .env (run tools/setup-bitlocker-secret.sh)"; exit 1; }
ARCH="${1:-arm64}"; OUT=out; DESK="--fleet-desktop"; [ "${NO_DESKTOP:-0}" = 1 ] && { OUT=out/no-desktop; DESK=""; }; mkdir -p "$OUT"
( cd "$OUT" && fleetctl package --type=msi --arch="$ARCH" --fleet-url="${FLEET_URL:-https://fleet.mpc.ad}" \
    --enroll-secret="$FLEET_WINDOWS_BITLOCKER_LAB_ENROLL_SECRET" \
    $DESK --enable-scripts --disable-open-folder 2>&1 | grep -v -i secret | tail -4 )
ls -la "$OUT"/*.msi 2>/dev/null
