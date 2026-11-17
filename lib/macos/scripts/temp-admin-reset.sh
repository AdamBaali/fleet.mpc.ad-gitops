#!/bin/bash
# Lets a Mac take temporary admin rights again before its cooldown ends.
# IT support runs this saved script when a user needs a second grant the same day.
# It clears the marker that temp-admin.sh writes, and doesn't change anyone's rights.
# The self-service item comes back at the next label refresh, about hourly, but the user
# can run temp-admin.sh as soon as this finishes.

MARKER="/Library/Application Support/Fleet/temp-admin-last-run"

if [ -f "$MARKER" ]; then
  /bin/rm -f "$MARKER"
  echo "Cooldown cleared. The user can take admin rights again."
else
  echo "No cooldown on this Mac. Nothing changed."
fi
exit 0
