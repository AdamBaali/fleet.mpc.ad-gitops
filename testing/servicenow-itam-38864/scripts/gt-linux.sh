#!/usr/bin/env bash
# Ground truth for the Linux ITAM tests (L-1 to L-3, U-1, U-4). Run with sudo on the test host.
#
# Usage: sudo ./gt-linux.sh <action>
#   install     install PKG with the host's package manager (L-1 on RPM, L-2 on DEB)
#   open        run PKG_BIN once (L-3)
#   upgrade     downgrade then upgrade PKG when the repos carry two versions, else reinstall (L-2)
#   uninstall   remove PKG (U-1)
#   reinstall   install PKG again after uninstall (U-4)
#   facts       print the package manager, osquery version and mount options L-3 depends on
# Detects apt, dnf, or rpm-ostree (atomic hosts, applied live so no reboot is needed).
# Each action appends to ../ground-truth/<host>.tsv.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/gt-lib.sh"

# ---- Test package (change here). GNU hello is small and ships in Debian, Ubuntu and Fedora. ----
PKG="${PKG:-hello}"
PKG_BIN="${PKG_BIN:-hello}"
# --------------------------------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

if [ -e /run/ostree-booted ]; then PM=rpm-ostree; SRC=rpm; T_INST=L-1
elif command -v apt-get >/dev/null; then PM=apt; SRC=deb; T_INST=L-2
elif command -v dnf >/dev/null; then PM=dnf; SRC=rpm; T_INST=L-1
else echo "no supported package manager" >&2; exit 1; fi

pkg_ver() {
  if [ "$SRC" = deb ]; then dpkg-query -W -f='${Version}' "$PKG" 2>/dev/null || true
  else rpm -q --qf '%{VERSION}' "$PKG" 2>/dev/null | grep -v 'not installed' || true; fi
}
publisher() {
  if [ "$SRC" = deb ]; then dpkg-query -W -f='${Maintainer}' "$PKG" 2>/dev/null | sed 's/ <.*//' || true
  else rpm -q --qf '%{VENDOR}' "$PKG" 2>/dev/null || true; fi
}

do_install() { # test_id event
  case "$PM" in
    apt) DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$PKG" >/dev/null ;;
    dnf) dnf install -y -q "$PKG" >/dev/null ;;
    rpm-ostree) rpm-ostree install --apply-live -y "$PKG" >/dev/null ;;
  esac
  gt_record "$1" linux "$PKG" "$PKG" "$(pkg_ver)" "$PM" "$2" "$(publisher)"
}

do_upgrade() {
  local method=reinstall
  case "$PM" in
    apt)
      local old; old="$(apt-cache madison "$PKG" | awk '{print $3}' | sort -uV | head -1)"
      if [ -n "$old" ] && [ "$old" != "$(pkg_ver)" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y -q --allow-downgrades "$PKG=$old" >/dev/null
        DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$PKG" >/dev/null; method=apt-downgrade-upgrade
      else DEBIAN_FRONTEND=noninteractive apt-get install -y -q --reinstall "$PKG" >/dev/null; fi ;;
    dnf)
      if dnf downgrade -y -q "$PKG" >/dev/null 2>&1; then dnf upgrade -y -q "$PKG" >/dev/null; method=dnf-downgrade-upgrade
      else dnf reinstall -y -q "$PKG" >/dev/null; fi ;;
    rpm-ostree) echo "rpm-ostree: layered packages update with the image; recording an uninstall and reinstall instead" >&2
      rpm-ostree uninstall --apply-live -y "$PKG" >/dev/null 2>&1 || true
      rpm-ostree install --apply-live -y "$PKG" >/dev/null; method=rpm-ostree-relayer ;;
  esac
  gt_record "L-2" linux "$PKG" "$PKG" "$(pkg_ver)" "$method" upgrade "$(publisher)"
}

case "${1:-}" in
  install)   do_install "$T_INST" install ;;
  reinstall) do_install "U-4" reinstall ;;
  open)      command -v "$PKG_BIN" >/dev/null && "$PKG_BIN" >/dev/null
             gt_record "L-3" linux "$PKG" "$PKG" "$(pkg_ver)" run open ;;
  upgrade)   do_upgrade ;;
  uninstall)
    case "$PM" in
      apt) DEBIAN_FRONTEND=noninteractive apt-get remove -y -q "$PKG" >/dev/null ;;
      dnf) dnf remove -y -q "$PKG" >/dev/null ;;
      rpm-ostree) rpm-ostree uninstall --apply-live -y "$PKG" >/dev/null ;;
    esac
    gt_record "U-1" linux "$PKG" "$PKG" "" "$PM" uninstall ;;
  facts)
    echo "package_manager=$PM source=${SRC}_packages"
    findmnt -no TARGET,OPTIONS / /usr 2>/dev/null || true
    ls /opt/orbit/bin/osqueryd/*/*/osqueryd 2>/dev/null | head -1 | xargs -r -I{} {} --version ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
