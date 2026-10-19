#!/usr/bin/env bash
# Ground truth for the macOS ITAM tests (M-1 to M-4, X-4 to X-7, U-1). Run with sudo on the test Mac.
#
# Usage: sudo ./gt-macos.sh <action>
#   dmg-install       install DMG_OLD by drag copy (M-1, X-4)
#   dmg-upgrade       replace it with DMG_NEW (M-2, X-6)
#   pkg-install       install PKG_OLD with installer (M-1, X-4)
#   pkg-upgrade       install PKG_NEW over it (M-2, X-6)
#   fma-wait          wait for FMA_PATH to appear after you click Install in Fleet, then record (M-1, X-4)
#   appstore-wait     wait for APPSTORE_PATH after you install it from the App Store, then record (M-4, X-5)
#   unsigned-install  build an unsigned app bundle (M-4, X-5)
#   open              open every installed test app as the console user, 15 s each (M-3)
#   uninstall         remove the DMG app (U-1, X-7)
#   reinstall         reinstall DMG_NEW after uninstall (X-7)
#   all-installs      dmg-install, pkg-install, unsigned-install
# Each action appends to ../ground-truth/<host>.tsv. Re-running an action records a new event.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/gt-lib.sh"

# ---- Test apps (change here). Publishers are company names, so no person names reach the results. ----
DMG_APP="VLC";              DMG_PATH="/Applications/VLC.app";   DMG_PUBLISHER="VideoLAN"
DMG_OLD_VER="3.0.20";       DMG_OLD="https://get.videolan.org/vlc/3.0.20/macosx/vlc-3.0.20-universal.dmg"
DMG_NEW_VER="3.0.21";       DMG_NEW="https://get.videolan.org/vlc/3.0.21/macosx/vlc-3.0.21-universal.dmg"
PKG_APP="Firefox";          PKG_PATH="/Applications/Firefox.app"; PKG_PUBLISHER="Mozilla"
PKG_OLD_VER="131.0";        PKG_OLD="https://ftp.mozilla.org/pub/firefox/releases/131.0/mac/en-US/Firefox%20131.0.pkg"
PKG_NEW_VER="132.0";        PKG_NEW="https://ftp.mozilla.org/pub/firefox/releases/132.0/mac/en-US/Firefox%20132.0.pkg"
FMA_APP="Google Chrome";    FMA_PATH="/Applications/Google Chrome.app"; FMA_PUBLISHER="Google"
APPSTORE_APP="${APPSTORE_APP:-Pages}"; APPSTORE_PATH="${APPSTORE_PATH:-/Applications/Pages.app}"; APPSTORE_PUBLISHER="${APPSTORE_PUBLISHER:-Apple}"
UNSIGNED_APP="ITAMUnsigned"; UNSIGNED_PATH="/Applications/ITAMUnsigned.app"
# ---------------------------------------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
CONSOLE_USER="$(stat -f %Su /dev/console)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }
ver_of() { /usr/bin/defaults read "$1/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo ""; }

dmg_copy() { # url test_id event method
  fetch "$1" "$WORK/a.dmg"
  local mnt; mnt="$(hdiutil attach -nobrowse -readonly "$WORK/a.dmg" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
  rm -rf "$DMG_PATH"
  ditto "$mnt/$(basename "$DMG_PATH")" "$DMG_PATH"
  hdiutil detach -quiet "$mnt"
  gt_record "$2" macos "$DMG_APP" "$DMG_PATH" "$(ver_of "$DMG_PATH")" "$4" "$3" "$DMG_PUBLISHER"
}

pkg_inst() { # url test_id event
  fetch "$1" "$WORK/a.pkg"
  installer -pkg "$WORK/a.pkg" -target / >/dev/null
  gt_record "$2" macos "$PKG_APP" "$PKG_PATH" "$(ver_of "$PKG_PATH")" pkg "$3" "$PKG_PUBLISHER"
}

unsigned_build() {
  rm -rf "$UNSIGNED_PATH"
  mkdir -p "$UNSIGNED_PATH/Contents/MacOS"
  cat > "$UNSIGNED_PATH/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.example.itamunsigned</string>
<key>CFBundleName</key><string>$UNSIGNED_APP</string>
<key>CFBundleExecutable</key><string>run</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PL
  printf '#!/bin/sh\nexit 0\n' > "$UNSIGNED_PATH/Contents/MacOS/run"
  chmod 755 "$UNSIGNED_PATH/Contents/MacOS/run"
  # "-" as expected publisher: compare.py passes when the publisher is empty.
  gt_record "M-4" macos "$UNSIGNED_APP" "$UNSIGNED_PATH" "1.0" build install "-" "unsigned bundle"
}

open_app() { # path name test_id
  [ -d "$1" ] || return 0
  sudo -u "$CONSOLE_USER" open -a "$1"
  gt_record "$3" macos "$2" "$1" "$(ver_of "$1")" open open
  sleep 15
  sudo -u "$CONSOLE_USER" osascript -e "quit app \"$2\"" >/dev/null 2>&1 || true
}

case "${1:-}" in
  dmg-install)      dmg_copy "$DMG_OLD" "M-1" install dmg ;;
  dmg-upgrade)      dmg_copy "$DMG_NEW" "M-2" upgrade dmg ;;
  pkg-install)      pkg_inst "$PKG_OLD" "M-1" install ;;
  pkg-upgrade)      pkg_inst "$PKG_NEW" "M-2" upgrade ;;
  fma-wait)         echo "Click Install for $FMA_APP on this host in Fleet now."; gt_wait_for "$FMA_PATH"
                    gt_record "M-1" macos "$FMA_APP" "$FMA_PATH" "$(ver_of "$FMA_PATH")" fleet-maintained-app install "$FMA_PUBLISHER" ;;
  appstore-wait)    echo "Install $APPSTORE_APP from the App Store now."; gt_wait_for "$APPSTORE_PATH"
                    gt_record "M-4" macos "$APPSTORE_APP" "$APPSTORE_PATH" "$(ver_of "$APPSTORE_PATH")" app-store install "$APPSTORE_PUBLISHER" ;;
  unsigned-install) unsigned_build ;;
  open)             open_app "$DMG_PATH" "$DMG_APP" M-3; open_app "$PKG_PATH" "$PKG_APP" M-3; open_app "$FMA_PATH" "$FMA_APP" M-3 ;;
  uninstall)        rm -rf "$DMG_PATH"; gt_record "U-1" macos "$DMG_APP" "$DMG_PATH" "" rm uninstall ;;
  reinstall)        dmg_copy "$DMG_NEW" "X-7" reinstall dmg ;;
  all-installs)     dmg_copy "$DMG_OLD" "M-1" install dmg; pkg_inst "$PKG_OLD" "M-1" install; unsigned_build ;;
  *) sed -n '2,19p' "$0"; exit 2 ;;
esac
