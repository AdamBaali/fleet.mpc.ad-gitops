# X-5: Package with an older fleetd

- **Started:** 2026-10-27T10:24:41Z
- **Objective:** Build the bypass package with fleetd (orbit and Fleet Desktop) 1.58.0, set up a fresh VM with it, reset it, then set fleet 10 update_channels to stable
- **Expected:** fleetd comes back at 1.58.0 after the reset; it updates only when Fleet sets update_channels

## Steps and evidence
- `01-build-msi-1.58.0.txt`: `OLD=1.58.0 tools/build-msis.sh arm64`
- `002-builder-in-utm.png` (window screenshot: UTM / ppkg-builder)

The v1 builder VM (ppkg-builder) no longer boots: Automatic Repair on QEMU, "Display output is not active" with no guest agent in UTM (002). A new builder (builder2) is a QEMU overlay of the golden image, left at the region screen, with the ADK installed as in S-4.
- `02-builder2-adk-install.txt`: `tools/qga.sh builder2 'New-Item -ItemType Directory -Force C:\build | Out-Null; Invoke-WebRequest -UseBasicPar`
