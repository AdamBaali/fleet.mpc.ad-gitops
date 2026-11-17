#!/bin/bash
# Gives the logged-in user admin rights for a set time, then makes them standard again.
#
# Run it from Fleet as a saved script (IT support with the Technician role can run saved
# scripts but can't edit them), or as a self-service script-only package scoped by a label.
#
# The demotion runs from a LaunchDaemon that checks an expiry time every minute. A timer
# that sleeps for 20 minutes would stop counting while the Mac sleeps and would be lost
# on restart. Checking a stored expiry time demotes the user on the first check after the
# time passes, including right after a restart.

DURATION_MINUTES=20

LABEL="com.fleetdm.temp-admin"
STATE_DIR="/Library/Application Support/Fleet/temp-admin"
DEMOTE_SCRIPT="$STATE_DIR/demote.sh"
STATE_FILE="$STATE_DIR/state"
DAEMON_PLIST="/Library/LaunchDaemons/$LABEL.plist"
LOG_FILE="/var/log/fleet-temp-admin.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root. Fleet runs scripts as root."
  exit 1
fi

console_user=$(/usr/bin/stat -f%Su /dev/console)

# Nobody is signed in at the login window, or Setup Assistant is still running.
if [ -z "$console_user" ] || [ "$console_user" = "root" ] || [ "$console_user" = "_mbsetupuser" ] || [ "$console_user" = "loginwindow" ]; then
  log "No user is signed in. Nothing changed."
  exit 1
fi

# Only demote users this script promoted. If the user is already an admin and has no
# active grant, they're a permanent admin and must stay one.
if [ -f "$STATE_FILE" ]; then
  granted_user=$(/usr/bin/awk -F= '$1=="user"{print $2}' "$STATE_FILE")
else
  granted_user=""
fi

if /usr/sbin/dseditgroup -o checkmember -m "$console_user" admin >/dev/null 2>&1; then
  if [ "$granted_user" != "$console_user" ]; then
    log "$console_user is already an admin without a temporary grant. Nothing changed."
    exit 0
  fi
  # A repeat run during an active grant restarts the clock.
  log "$console_user has an active grant. Restarting the clock."
fi

# A grant for a different user is still active. Demote that user first so two people
# can't hold temporary admin on one Mac and only one gets demoted.
if [ -n "$granted_user" ] && [ "$granted_user" != "$console_user" ]; then
  /usr/sbin/dseditgroup -o edit -d "$granted_user" -t user admin
  log "Removed the earlier grant for $granted_user."
fi

/bin/mkdir -p "$STATE_DIR"
/bin/chmod 700 "$STATE_DIR"

expires=$(( $(date +%s) + DURATION_MINUTES * 60 ))
printf 'user=%s\nexpires=%s\n' "$console_user" "$expires" > "$STATE_FILE"
/bin/chmod 600 "$STATE_FILE"

# The demote script is written fresh on every run so a changed script in Fleet takes
# effect on the next grant.
/bin/cat > "$DEMOTE_SCRIPT" <<EOF
#!/bin/bash
STATE_FILE="$STATE_FILE"
LOG_FILE="$LOG_FILE"
LABEL="$LABEL"
DAEMON_PLIST="$DAEMON_PLIST"
STATE_DIR="$STATE_DIR"
EOF
/bin/cat >> "$DEMOTE_SCRIPT" <<'EOF'
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

cleanup() {
  /bin/rm -f "$DAEMON_PLIST"
  /bin/rm -rf "$STATE_DIR"
  /bin/launchctl bootout system/"$LABEL" 2>/dev/null
}

if [ ! -f "$STATE_FILE" ]; then
  log "No grant on record. Removing the daemon."
  cleanup
  exit 0
fi

user=$(/usr/bin/awk -F= '$1=="user"{print $2}' "$STATE_FILE")
expires=$(/usr/bin/awk -F= '$1=="expires"{print $2}' "$STATE_FILE")

[ "$(date +%s)" -lt "${expires:-0}" ] && exit 0

if /usr/sbin/dseditgroup -o checkmember -m "$user" admin >/dev/null 2>&1; then
  if /usr/sbin/dseditgroup -o edit -d "$user" -t user admin; then
    log "Grant expired. $user is a standard user again."
  else
    # Keep the daemon so the next check tries again.
    log "Grant expired, but removing $user from admin failed. Retrying in a minute."
    exit 1
  fi
else
  log "Grant expired. $user was already removed from admin."
fi
cleanup
EOF
/usr/sbin/chown root:wheel "$DEMOTE_SCRIPT"
/bin/chmod 700 "$DEMOTE_SCRIPT"

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
    <string>$DEMOTE_SCRIPT</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>60</integer>
</dict>
</plist>
EOF
/usr/sbin/chown root:wheel "$DAEMON_PLIST"
/bin/chmod 644 "$DAEMON_PLIST"

# Reload so a repeat run picks up the new plist.
/bin/launchctl bootout system/"$LABEL" 2>/dev/null
if ! /bin/launchctl bootstrap system "$DAEMON_PLIST"; then
  log "Couldn't load the demotion daemon. Not granting admin."
  /bin/rm -f "$DAEMON_PLIST"
  /bin/rm -rf "$STATE_DIR"
  exit 1
fi

if ! /usr/sbin/dseditgroup -o checkmember -m "$console_user" admin >/dev/null 2>&1; then
  if ! /usr/sbin/dseditgroup -o edit -a "$console_user" -t user admin; then
    log "Adding $console_user to admin failed."
    exit 1
  fi
fi

log "$console_user is an admin until $(date -r "$expires" '+%Y-%m-%d %H:%M:%S %Z')."
exit 0
