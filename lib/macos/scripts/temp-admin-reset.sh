#!/bin/bash
# Lets a Mac take temporary admin rights again before its cooldown ends.
# IT support runs this saved script when a user needs a second grant the same day.
# It clears the marker that temp-admin.sh writes, and doesn't change anyone's rights.
# It then asks Fleet to refetch the host so the self-service item comes back on the next
# check-in instead of at the hourly label refresh.

MARKER="/Library/Application Support/Fleet/temp-admin-last-run"

# Same call as in temp-admin.sh. The token file is readable by every local user already,
# so putting it in the URL exposes nothing new.
request_refetch() {
  local url token code
  url=$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:ORBIT_FLEET_URL' /Library/LaunchDaemons/com.fleetdm.orbit.plist 2>/dev/null)
  token=$(/bin/cat /opt/orbit/identifier 2>/dev/null)
  if [ -z "$url" ] || [ -z "$token" ]; then
    echo "Couldn't find the Fleet URL or device token. The item comes back at the next label refresh."
    return
  fi
  code=$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X POST "${url%/}/api/latest/fleet/device/$token/refetch")
  if [ "$code" = "200" ]; then
    echo "Asked Fleet to refetch this host."
  else
    echo "Refetch request returned HTTP $code. The item comes back at the next label refresh."
  fi
}

if [ -f "$MARKER" ]; then
  /bin/rm -f "$MARKER"
  echo "Cooldown cleared. The user can take admin rights again."
  request_refetch
else
  echo "No cooldown on this Mac. Nothing changed."
fi
exit 0
