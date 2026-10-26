#!/bin/bash
# Builds MSI-B (bypass) and MSI-N (no bypass) for Windows Reset Lab into out/ (TEST_PLAN S-5). Arm64 for the UTM VM.
# The enroll secret is read from private/.env and never printed. Needs Docker running and fleetctl matching the server.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . private/.env; set +a
[ -n "${FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET:-}" ] || { echo "FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET missing in private/.env"; exit 1; }
ARCH="${1:-arm64}"
build() { # dir, extra flags
  mkdir -p "out/$1"
  ( cd "out/$1" && fleetctl package --type=msi --arch="$ARCH" --fleet-url=https://fleet.mpc.ad \
      --enroll-secret="$FLEET_WINDOWS_RESET_LAB_ENROLL_SECRET" --fleet-desktop --enable-scripts \
      --disable-setup-experience $2 --disable-open-folder 2>&1 | grep -v -i secret | tail -3 )
}
build msi-b "--bypass-end-user-auth"
build msi-n ""
ls -la out/msi-b/*.msi out/msi-n/*.msi
