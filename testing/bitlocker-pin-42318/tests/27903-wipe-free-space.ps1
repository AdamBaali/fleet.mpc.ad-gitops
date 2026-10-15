# fleetdm/fleet#27903 test 2: wipe the free space of a Used Space Only C: (Microsoft: "manage-bde -w").
"start: " + (Get-Date -Format o)
manage-bde -w C:
"manage-bde -w exit code: $LASTEXITCODE"
"end: " + (Get-Date -Format o)
manage-bde -status C:
