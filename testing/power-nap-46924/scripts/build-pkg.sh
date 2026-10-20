#!/usr/bin/env bash
# Builds the fleetd installer that enrolls a Mac in Power Nap Lab (fleetdm/fleet#46924).
# Usage: testing/power-nap-46924/scripts/build-pkg.sh [output folder, default ~/Downloads]
#
# The enroll secret is read from Fleet at build time, so it is never stored in the repo.
# The pkg holds it, so keep the pkg out of the repo and don't share it.
# --enable-scripts is required: the flag-file policy runs a script (PN-3).
set -euo pipefail
out="${1:-$HOME/Downloads}"
fleet_id=8  # Power Nap Lab
url="$(awk '/^contexts:/{c=1} c && /address:/{print $2; exit}' ~/.fleet/config)"
secret="$(fleetctl api "/api/v1/fleet/teams/$fleet_id/secrets" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["secrets"][0]["secret"])')"
[ -n "$secret" ] || { echo "no enroll secret for fleet $fleet_id" >&2; exit 1; }
mkdir -p "$out"
cd "$out"
fleetctl package --type=pkg --fleet-url="$url" --enroll-secret="$secret" \
  --enable-scripts --fleet-desktop --outfile="$out/fleet-power-nap-lab.pkg"
echo "Built $out/fleet-power-nap-lab.pkg for $url"
