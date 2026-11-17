#!/bin/bash
# Runs privileges-approve.sh and the watcher it writes against stubs, without root and
# without touching the Mac. It checks the approval and the one-use logic, not macOS or SAP
# Privileges: dseditgroup, dscl, launchctl, and the console user are fakes, and "Privileges
# grants admin" is simulated by adding the user to the fake admin group. The real behavior
# is tested on a lab Mac (TEST_PLAN.md, option 2).
#
# Usage: testing/macos-temp-admin/scripts/privileges-harness.sh
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/Fleet" "$T/LaunchDaemons" "$T/log" "$T/groups"
: > "$T/groups/admin"
CONSOLE="$T/console"; echo testuser > "$CONSOLE"

# Fake dseditgroup and dscl: one file per group, one member per line.
cat > "$T/bin/dseditgroup" <<EOF
#!/bin/bash
G="$T/groups"
case "\$2" in
  checkmember) [ -f "\$G/\$5" ] && grep -qx "\$4" "\$G/\$5" ;;
  create) : > "\$G/\${!#}" ;;
  edit)
    [ -f "\$G/\$7" ] || exit 1
    case "\$3" in
      -a) grep -qx "\$4" "\$G/\$7" || echo "\$4" >> "\$G/\$7" ;;
      -d) grep -vx "\$4" "\$G/\$7" > "\$G/\$7.tmp"; mv "\$G/\$7.tmp" "\$G/\$7" ;;
    esac ;;
esac
EOF
cat > "$T/bin/dscl" <<EOF
#!/bin/bash
[ -f "$T/groups/\${3#/Groups/}" ]
EOF
printf '#!/bin/bash\n[ -f "%s/launchctl-fails" ] && [ "$1" = bootstrap ] && exit 5\nexit 0\n' "$T" > "$T/bin/launchctl"
printf '#!/bin/bash\nexit 0\n' > "$T/bin/chown"
chmod +x "$T/bin/"*

sed -e "s#/usr/sbin/dseditgroup#$T/bin/dseditgroup#g" \
    -e "s#/usr/bin/dscl#$T/bin/dscl#g" \
    -e "s#/bin/launchctl#$T/bin/launchctl#g" \
    -e "s#/usr/sbin/chown#$T/bin/chown#g" \
    -e "s#/usr/bin/stat -f%Su /dev/console#cat $CONSOLE#g" \
    -e "s#/Library/Application Support/Fleet#$T/Fleet#g" \
    -e "s#/Library/LaunchDaemons#$T/LaunchDaemons#g" \
    -e "s#/var/log/#$T/log/#g" \
    -e 's#\[ "$(id -u)" -ne 0 \]#false#' \
    "$REPO/lib/macos/scripts/privileges-approve.sh" > "$T/approve.sh"

WATCHER="$T/Fleet/privileges-once/watch.sh"
PLIST="$T/LaunchDaemons/com.fleetdm.privileges-once.plist"
pass=0; fail=0
check() { if eval "$2"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }
in_group() { [ -f "$T/groups/$2" ] && grep -qx "$1" "$T/groups/$2"; }
approve() { out=$(bash "$T/approve.sh" 2>&1); rc=$?; }
watch() { [ -f "$WATCHER" ] && bash "$WATCHER"; }
privileges_grants() { echo "$1" >> "$T/groups/admin"; }
privileges_revokes() { grep -vx "$1" "$T/groups/admin" > "$T/groups/admin.tmp"; mv "$T/groups/admin.tmp" "$T/groups/admin"; }

echo "== 1. IT support approves a standard user"
approve
check "exits 0, group created, user in fleet-temp-admin" '[ $rc -eq 0 ] && in_group testuser fleet-temp-admin'
check "watcher LaunchDaemon written" '[ -f "$PLIST" ] && [ -f "$WATCHER" ]'
approve
check "approving again changes nothing" '[ $rc -eq 0 ] && grep -q "Nothing changed" <<<"$out"'

echo "== 2. Watcher while the approval is unused"
watch; watch
check "user stays approved" 'in_group testuser fleet-temp-admin && [ -f "$PLIST" ]'

echo "== 3. User takes admin in Privileges"
privileges_grants testuser; watch
check "user stays in the group during the grant" 'in_group testuser fleet-temp-admin'
approve
check "approving during the grant changes nothing" '[ $rc -eq 0 ] && grep -q "still running" <<<"$out"'

echo "== 4. Privileges ends the grant"
privileges_revokes testuser; watch
check "approval used up: user out of the group" '! in_group testuser fleet-temp-admin'
check "watcher removed itself" '[ ! -f "$PLIST" ] && [ ! -e "$T/Fleet/privileges-once" ]'

echo "== 5. A new approval allows one more grant"
approve
check "user back in the group with a new watcher" '[ $rc -eq 0 ] && in_group testuser fleet-temp-admin && [ -f "$PLIST" ]'

echo "== 6. IT support removes an unused approval by hand"
"$T/bin/dseditgroup" -o edit -d testuser -t user fleet-temp-admin; watch
check "watcher cleans up" '[ ! -f "$PLIST" ] && [ ! -e "$T/Fleet/privileges-once" ]'

echo "== 7. A second user's approval replaces the first"
approve; echo seconduser > "$CONSOLE"; approve
check "first user out, second user in" '! in_group testuser fleet-temp-admin && in_group seconduser fleet-temp-admin'
"$T/bin/dseditgroup" -o edit -d seconduser -t user fleet-temp-admin; watch

echo "== 8. The watcher fails to load"
echo testuser > "$CONSOLE"; touch "$T/launchctl-fails"; approve; rm -f "$T/launchctl-fails"
check "exits 1 and doesn't approve" '[ $rc -eq 1 ] && ! in_group testuser fleet-temp-admin && [ ! -f "$PLIST" ]'

echo "== 9. Negative control: a permanent admin"
echo permadmin >> "$T/groups/admin"; echo permadmin > "$CONSOLE"
approve
check "exits 0 with no change" '[ $rc -eq 0 ] && grep -q "already an admin" <<<"$out" && ! in_group permadmin fleet-temp-admin'

echo "== 10. Negative control: nobody signed in"
echo root > "$CONSOLE"
approve
check "exits 1" '[ $rc -eq 1 ]'

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
