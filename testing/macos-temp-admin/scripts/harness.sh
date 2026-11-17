#!/bin/bash
# Runs temp-admin.sh and temp-admin-reset.sh against stubs, without root and without
# touching the Mac. It checks the marker logic and the order of steps, not macOS itself:
# dseditgroup, launchctl, curl, and the console user are fakes. The real macOS behavior
# is tested on a lab Mac (TEST_PLAN.md T-2 to T-12).
#
# Usage: testing/macos-temp-admin/scripts/harness.sh
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/Fleet" "$T/LaunchDaemons" "$T/log"
ADMINS="$T/admins"; : > "$ADMINS"
CONSOLE="$T/console"; echo testuser > "$CONSOLE"
echo fake-device-token > "$T/identifier"

# Fake dseditgroup: keeps admin membership in a text file.
cat > "$T/bin/dseditgroup" <<EOF
#!/bin/bash
case "\$*" in
  *checkmember*) grep -qx "\$4" "$ADMINS" ;;
  *"-a "*) echo "\$4" >> "$ADMINS" ;;
  *"-d "*) grep -vx "\$4" "$ADMINS" > "$ADMINS.tmp"; mv "$ADMINS.tmp" "$ADMINS" ;;
esac
EOF
printf '#!/bin/bash\nexit 0\n' > "$T/bin/launchctl"
printf '#!/bin/bash\nexit 0\n' > "$T/bin/chown"
printf '#!/bin/bash\necho https://fleet.example.invalid\n' > "$T/bin/PlistBuddy"
printf '#!/bin/bash\necho "$*" >> "%s/curl-calls"\necho 200\n' "$T" > "$T/bin/curl"
chmod +x "$T/bin/"*

# Point every system path the scripts use at the stubs and the scratch folder.
stub() {
  sed -e "s#/usr/sbin/dseditgroup#$T/bin/dseditgroup#g" \
      -e "s#/bin/launchctl#$T/bin/launchctl#g" \
      -e "s#/usr/sbin/chown#$T/bin/chown#g" \
      -e "s#/usr/libexec/PlistBuddy#$T/bin/PlistBuddy#g" \
      -e "s#/usr/bin/curl#$T/bin/curl#g" \
      -e "s#/usr/bin/stat -f%Su /dev/console#cat $CONSOLE#g" \
      -e "s#/Library/Application Support/Fleet#$T/Fleet#g" \
      -e "s#/Library/LaunchDaemons#$T/LaunchDaemons#g" \
      -e "s#/var/log/#$T/log/#g" \
      -e "s#/opt/orbit/identifier#$T/identifier#g" \
      -e 's#\[ "$(id -u)" -ne 0 \]#false#' \
      "$1" > "$2"
}
stub "$REPO/lib/macos/scripts/temp-admin.sh" "$T/grant.sh"
stub "$REPO/lib/macos/scripts/temp-admin-reset.sh" "$T/reset.sh"

MARKER="$T/Fleet/temp-admin-last-run"
STATE="$T/Fleet/temp-admin/state"
PLIST="$T/LaunchDaemons/com.fleetdm.temp-admin.plist"
pass=0; fail=0
check() { if eval "$2"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }
is_admin() { grep -qx "$1" "$ADMINS"; }
calls() { [ -f "$T/curl-calls" ] && wc -l < "$T/curl-calls" | tr -d ' ' || echo 0; }

echo "== 1. First grant for a standard user"
out=$(bash "$T/grant.sh" 2>&1); rc=$?
check "exits 0" '[ $rc -eq 0 ]'
check "user is an admin" 'is_admin testuser'
check "marker written" '[ -f "$MARKER" ]'
check "LaunchDaemon written" '[ -f "$PLIST" ]'
check "refetch requested once, at the device refetch endpoint" '[ "$(calls)" = 1 ] && grep -q "/api/latest/fleet/device/fake-device-token/refetch" "$T/curl-calls"'

echo "== 2. Second run while the marker exists"
out=$(bash "$T/grant.sh" 2>&1); rc=$?
check "exits 1" '[ $rc -eq 1 ]'
check "says it was already used" 'grep -q "already used on this Mac" <<<"$out"'
check "no second refetch" '[ "$(calls)" = 1 ]'

echo "== 3. Grant expires and the LaunchDaemon's script runs"
sed -i '' "s/^expires=.*/expires=1/" "$STATE"
bash "$T/Fleet/temp-admin/demote.sh"
check "user is standard again" '! is_admin testuser'
check "state and LaunchDaemon removed" '[ ! -e "$STATE" ] && [ ! -f "$PLIST" ]'
check "marker kept after the grant ends" '[ -f "$MARKER" ]'

echo "== 4. A run after expiry is still refused"
out=$(bash "$T/grant.sh" 2>&1); rc=$?
check "exits 1 and stays standard" '[ $rc -eq 1 ] && ! is_admin testuser'

echo "== 5. IT support resets"
out=$(bash "$T/reset.sh" 2>&1); rc=$?
check "exits 0 and removes the marker" '[ $rc -eq 0 ] && [ ! -f "$MARKER" ]'
check "reset requests a refetch" '[ "$(calls)" = 2 ]'
out=$(bash "$T/reset.sh" 2>&1)
check "a second reset changes nothing" 'grep -q "Nothing changed" <<<"$out" && [ "$(calls)" = 2 ]'

echo "== 6. Grant works again after the reset"
out=$(bash "$T/grant.sh" 2>&1); rc=$?
check "exits 0, admin again, marker back" '[ $rc -eq 0 ] && is_admin testuser && [ -f "$MARKER" ]'

echo "== 7. Negative control: a permanent admin"
rm -rf "$T/Fleet/temp-admin" "$MARKER" "$PLIST"; : > "$ADMINS"; echo permadmin > "$ADMINS"; echo permadmin > "$CONSOLE"
out=$(bash "$T/grant.sh" 2>&1); rc=$?
check "exits 0 with no change" '[ $rc -eq 0 ] && grep -q "already an admin" <<<"$out"'
check "no marker, no LaunchDaemon, still admin" '[ ! -f "$MARKER" ] && [ ! -f "$PLIST" ] && is_admin permadmin'

echo "== 8. Negative control: nobody signed in"
echo root > "$CONSOLE"
out=$(bash "$T/grant.sh" 2>&1); rc=$?
check "exits 1 with no marker" '[ $rc -eq 1 ] && [ ! -f "$MARKER" ]'

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
