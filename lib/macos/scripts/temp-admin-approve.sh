#!/bin/bash
# Approves this Mac for one temporary admin grant. IT support runs this saved script when
# someone needs admin, the same as adding the Mac to a static group. It writes the approval
# file that temp-admin.sh needs, and doesn't change anyone's rights. temp-admin.sh deletes
# the file after the grant, so each approval is good for one use.
# It then asks Fleet to refetch the host so the self-service item shows on the next
# check-in instead of at the hourly label refresh.

APPROVAL="/Library/Application Support/Fleet/temp-admin-approved"

# Same call as in temp-admin.sh. The token file is readable by every local user already,
# so putting it in the URL exposes nothing new.
request_refetch() {
  local url token code
  url=$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:ORBIT_FLEET_URL' /Library/LaunchDaemons/com.fleetdm.orbit.plist 2>/dev/null)
  token=$(/bin/cat /opt/orbit/identifier 2>/dev/null)
  if [ -z "$url" ] || [ -z "$token" ]; then
    echo "Couldn't find the Fleet URL or device token. The item shows at the next label refresh."
    return
  fi
  code=$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X POST "${url%/}/api/latest/fleet/device/$token/refetch")
  if [ "$code" = "200" ]; then
    echo "Asked Fleet to refetch this host."
  else
    echo "Refetch request returned HTTP $code. The item shows at the next label refresh."
  fi
}

if [ -f "$APPROVAL" ]; then
  echo "This Mac is already approved and the approval hasn't been used. Nothing changed."
  exit 0
fi

/bin/mkdir -p "$(dirname "$APPROVAL")"
/usr/bin/touch "$APPROVAL"
/bin/chmod 600 "$APPROVAL"
echo "Approved. The user can take admin rights once from Self-service."
request_refetch
exit 0
