#!/bin/bash
# Creates the enroll secret for the "Windows BitLocker Lab" fleet and stores it in the GitOps repo secrets. Run yourself. Nothing is printed.
set -euo pipefail
LAB="$(cd "$(dirname "$0")/.." && pwd)"; REPO="AdamBaali/fleet.mpc.ad-gitops"; NAME="FLEET_WINDOWS_BITLOCKER_LAB_ENROLL_SECRET"
touch "$LAB/.env"; chmod 600 "$LAB/.env"
grep -q "^$NAME=" "$LAB/.env" || { echo "$NAME=$(openssl rand -hex 24)" >> "$LAB/.env"; echo "generated a new secret in .env"; }
grep "^$NAME=" "$LAB/.env" | cut -d= -f2- | tr -d '\n' | gh secret set "$NAME" --repo "$REPO"
echo "repo secret $NAME set. Now push the GitOps repo (GitHub Desktop) so the fleet is created."
cd /Users/adam/Documents/GitHub/fleet.mpc.ad-gitops && git --no-pager log --oneline origin/main..HEAD
