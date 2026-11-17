#!/bin/bash
# Approves the signed-in user for one SAP Privileges grant. IT support runs this saved script
# when someone needs admin, the same as adding the Mac to a static group.
#
# The Privileges profile (privileges-temp-admin.mobileconfig) sets LimitToGroup to the local
# group fleet-temp-admin, so the app only works for its members. This script adds the user
# to that group and loads a watcher LaunchDaemon. The watcher waits until it has seen the
# user as an admin and then as standard again, which means the grant ended, and only then
# takes them out of the group. Removing them while the grant runs could end it early, and
# Privileges' docs don't say what it does in that case. The watcher removes itself after.

GROUP="fleet-temp-admin"
LABEL="com.fleetdm.privileges-once"
STATE_DIR="/Library/Application Support/Fleet/privileges-once"
WATCHER="$STATE_DIR/watch.sh"
STATE_FILE="$STATE_DIR/user"
DAEMON_PLIST="/Library/LaunchDaemons/$LABEL.plist"
LOG_FILE="/var/log/fleet-privileges-once.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root. Fleet runs scripts as root."
  exit 1
fi

console_user=$(/usr/bin/stat -f%Su /dev/console)
if [ -z "$console_user" ] || [ "$console_user" = "root" ] || [ "$console_user" = "_mbsetupuser" ] || [ "$console_user" = "loginwindow" ]; then
  log "No user is signed in. Nothing changed."
  exit 1
fi

if [ -f "$STATE_FILE" ]; then
  approved_user=$(/bin/cat "$STATE_FILE")
else
  approved_user=""
fi

if /usr/sbin/dseditgroup -o checkmember -m "$console_user" admin >/dev/null 2>&1 && [ "$approved_user" != "$console_user" ]; then
  log "$console_user is already an admin. Nothing changed."
  exit 0
fi

if ! /usr/bin/dscl . -read "/Groups/$GROUP" >/dev/null 2>&1; then
  if ! /usr/sbin/dseditgroup -o create -r "Fleet temp admin" "$GROUP"; then
    log "Couldn't create the $GROUP group. Nothing changed."
    exit 1
  fi
fi

if [ "$approved_user" = "$console_user" ] && /usr/sbin/dseditgroup -o checkmember -m "$console_user" "$GROUP" >/dev/null 2>&1; then
  log "$console_user is already approved, or their grant is still running. Nothing changed."
  exit 0
fi

# One approval per Mac at a time, so an earlier user's unused approval ends here.
if [ -n "$approved_user" ] && [ "$approved_user" != "$console_user" ]; then
  /usr/sbin/dseditgroup -o edit -d "$approved_user" -t user "$GROUP" 2>/dev/null
  log "Removed the earlier approval for $approved_user."
fi

/bin/mkdir -p "$STATE_DIR"
/bin/chmod 700 "$STATE_DIR"
/bin/rm -f "$STATE_DIR/seen-admin"
printf '%s\n' "$console_user" > "$STATE_FILE"

/bin/cat > "$WATCHER" <<EOF
#!/bin/bash
GROUP="$GROUP"
LABEL="$LABEL"
STATE_DIR="$STATE_DIR"
STATE_FILE="$STATE_FILE"
DAEMON_PLIST="$DAEMON_PLIST"
LOG_FILE="$LOG_FILE"
EOF
/bin/cat >> "$WATCHER" <<'EOF'
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

cleanup() {
  /bin/rm -f "$DAEMON_PLIST"
  /bin/rm -rf "$STATE_DIR"
  /bin/launchctl bootout system/"$LABEL" 2>/dev/null
}

user=$(/bin/cat "$STATE_FILE" 2>/dev/null)
if [ -z "$user" ]; then
  cleanup
  exit 0
fi

# IT support or someone else already took the user out of the group.
if ! /usr/sbin/dseditgroup -o checkmember -m "$user" "$GROUP" >/dev/null 2>&1; then
  log "$user is no longer in $GROUP. Removing the watcher."
  cleanup
  exit 0
fi

if /usr/sbin/dseditgroup -o checkmember -m "$user" admin >/dev/null 2>&1; then
  if [ ! -f "$STATE_DIR/seen-admin" ]; then
    /usr/bin/touch "$STATE_DIR/seen-admin"
    log "$user took admin rights with Privileges."
  fi
  exit 0
fi

# Standard user. Either the approval is unused, or the grant just ended.
if [ -f "$STATE_DIR/seen-admin" ]; then
  if /usr/sbin/dseditgroup -o edit -d "$user" -t user "$GROUP"; then
    log "Grant ended. $user's approval is used up."
    cleanup
  else
    log "Grant ended, but removing $user from $GROUP failed. Retrying."
  fi
fi
EOF
/usr/sbin/chown root:wheel "$WATCHER"
/bin/chmod 700 "$WATCHER"

/bin/cat > "$DAEMON_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$WATCHER</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>15</integer>
</dict>
</plist>
EOF
/usr/sbin/chown root:wheel "$DAEMON_PLIST"
/bin/chmod 644 "$DAEMON_PLIST"

# Load the watcher before approving, so an approval is never left without one.
/bin/launchctl bootout system/"$LABEL" 2>/dev/null
if ! /bin/launchctl bootstrap system "$DAEMON_PLIST"; then
  log "Couldn't load the watcher. Not approving."
  /bin/rm -f "$DAEMON_PLIST"
  /bin/rm -rf "$STATE_DIR"
  exit 1
fi

if ! /usr/sbin/dseditgroup -o edit -a "$console_user" -t user "$GROUP"; then
  log "Adding $console_user to $GROUP failed."
  exit 1
fi

log "Approved $console_user for one Privileges grant of 20 minutes."
exit 0
