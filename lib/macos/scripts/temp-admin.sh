#!/bin/bash
# Gives the logged-in user admin rights for a set time, then makes them standard again.
#
# The user runs it from Fleet Desktop self-service, or IT support runs it as a saved script.
#
# One grant per Mac until IT support resets it, like a policy that runs once per computer
# and gets flushed. Each grant writes a marker file. The script refuses while the marker
# exists, and a dynamic label on the same marker hides the self-service item. Labels
# refresh about hourly, so after writing the marker the script asks Fleet to refetch the
# host, which runs the label queries on the next check-in. The script's own check still
# enforces the limit if the refetch fails. IT support deletes the marker with
# temp-admin-reset.sh to allow another grant.
#
# The demotion runs from a LaunchDaemon that checks an expiry time every minute. A timer
# that sleeps for 20 minutes would stop counting while the Mac sleeps and would be lost
# on restart. Checking a stored expiry time demotes the user on the first check after the
# time passes, including right after a restart.

DURATION_MINUTES=20

# Kept outside STATE_DIR, which the demotion deletes, so the marker outlives the grant.
MARKER="/Library/Application Support/Fleet/temp-admin-last-run"

LABEL="com.fleetdm.temp-admin"
STATE_DIR="/Library/Application Support/Fleet/temp-admin"
DEMOTE_SCRIPT="$STATE_DIR/demote.sh"
STATE_FILE="$STATE_DIR/state"
DAEMON_PLIST="/Library/LaunchDaemons/$LABEL.plist"
LOG_FILE="/var/log/fleet-temp-admin.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

# Asks Fleet to refetch this host with its Fleet Desktop token, the same call Fleet
# Desktop's Refetch button makes. The token file is readable by every local user
# already, so putting it in the URL exposes nothing new. Best effort: a failure only
# delays the label update until the next hourly refresh.
request_refetch() {
  local url token code
  url=$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:ORBIT_FLEET_URL' /Library/LaunchDaemons/com.fleetdm.orbit.plist 2>/dev/null)
  token=$(/bin/cat /opt/orbit/identifier 2>/dev/null)
  if [ -z "$url" ] || [ -z "$token" ]; then
    log "Couldn't find the Fleet URL or device token. The label updates at the next refresh."
    return
  fi
  code=$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X POST "${url%/}/api/latest/fleet/device/$token/refetch")
  if [ "$code" = "200" ]; then
    log "Asked Fleet to refetch this host."
  else
    log "Refetch request returned HTTP $code. The label updates at the next refresh."
  fi
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
fi

if [ -f "$MARKER" ]; then
  log "Admin rights were already used on this Mac on $(date -r "$(/usr/bin/stat -f %m "$MARKER")" '+%Y-%m-%d %H:%M %Z'). Ask IT support to reset it."
  exit 1
fi

# Reached during an active grant only after IT support cleared the marker.
if [ "$granted_user" = "$console_user" ]; then
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

/usr/bin/touch "$MARKER"

log "$console_user is an admin until $(date -r "$expires" '+%Y-%m-%d %H:%M:%S %Z')."
request_refetch
exit 0
