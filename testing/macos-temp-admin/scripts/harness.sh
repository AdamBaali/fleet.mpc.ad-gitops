#!/bin/bash
# Runs temp-admin.sh and temp-admin-approve.sh against stubs, without root and without
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
# Fake launchctl: fails when the test creates a "launchctl-fails" file.
printf '#!/bin/bash\n[ -f "%s/launchctl-fails" ] && [ "$1" = bootstrap ] && exit 5\nexit 0\n' "$T" > "$T/bin/launchctl"
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
stub "$REPO/lib/macos/scripts/temp-admin-approve.sh" "$T/approve.sh"

APPROVAL="$T/Fleet/temp-admin-approved"
STATE="$T/Fleet/temp-admin/state"
PLIST="$T/LaunchDaemons/com.fleetdm.temp-admin.plist"
pass=0; fail=0
check() { if eval "$2"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }
is_admin() { grep -qx "$1" "$ADMINS"; }
calls() { [ -f "$T/curl-calls" ] && wc -l < "$T/curl-calls" | tr -d ' ' || echo 0; }
grant() { out=$(bash "$T/grant.sh" 2>&1); rc=$?; }
approve() { out=$(bash "$T/approve.sh" 2>&1); rc=$?; }

echo "== 1. Not approved"
grant
check "refused with exit 1" '[ $rc -eq 1 ] && grep -q "isn.t approved" <<<"$out"'
check "stays standard, no LaunchDaemon, no refetch" '! is_admin testuser && [ ! -f "$PLIST" ] && [ "$(calls)" = 0 ]'

echo "== 2. IT support approves"
approve
check "exits 0, approval file written, one refetch" '[ $rc -eq 0 ] && [ -f "$APPROVAL" ] && [ "$(calls)" = 1 ]'
check "refetch uses the device refetch endpoint" 'grep -q "/api/latest/fleet/device/fake-device-token/refetch" "$T/curl-calls"'
approve
check "approving again changes nothing" 'grep -q "Nothing changed" <<<"$out" && [ "$(calls)" = 1 ]'

echo "== 3. User takes the grant"
grant
check "exits 0 and user is an admin" '[ $rc -eq 0 ] && is_admin testuser'
check "approval used up" '[ ! -f "$APPROVAL" ]'
check "LaunchDaemon written and a refetch requested" '[ -f "$PLIST" ] && [ "$(calls)" = 2 ]'

echo "== 4. A second run without a new approval"
grant
check "refused, no refetch" '[ $rc -eq 1 ] && [ "$(calls)" = 2 ]'

echo "== 5. Grant expires and the LaunchDaemon's script runs"
sed -i '' "s/^expires=.*/expires=1/" "$STATE"
bash "$T/Fleet/temp-admin/demote.sh"
check "user is standard again" '! is_admin testuser'
check "state and LaunchDaemon removed" '[ ! -e "$STATE" ] && [ ! -f "$PLIST" ]'
grant
check "still refused after expiry" '[ $rc -eq 1 ] && ! is_admin testuser'

echo "== 6. A new approval allows one more grant"
approve; grant
check "admin again, approval used up" '[ $rc -eq 0 ] && is_admin testuser && [ ! -f "$APPROVAL" ]'

echo "== 7. A failed grant keeps the approval"
sed -i '' "s/^expires=.*/expires=1/" "$STATE"; bash "$T/Fleet/temp-admin/demote.sh"
approve; touch "$T/launchctl-fails"; grant; rm -f "$T/launchctl-fails"
check "exits 1, stays standard, approval kept" '[ $rc -eq 1 ] && ! is_admin testuser && [ -f "$APPROVAL" ]'

echo "== 8. Negative control: a permanent admin with an approval"
rm -rf "$T/Fleet/temp-admin" "$PLIST"; echo permadmin > "$ADMINS"; echo permadmin > "$CONSOLE"
grant
check "exits 0 with no change" '[ $rc -eq 0 ] && grep -q "already an admin" <<<"$out"'
check "approval kept, no LaunchDaemon, still admin" '[ -f "$APPROVAL" ] && [ ! -f "$PLIST" ] && is_admin permadmin'

echo "== 9. Negative control: nobody signed in"
echo root > "$CONSOLE"
grant
check "exits 1, approval kept" '[ $rc -eq 1 ] && [ -f "$APPROVAL" ]'

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
