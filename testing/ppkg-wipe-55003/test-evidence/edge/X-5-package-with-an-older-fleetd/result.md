# X-5: Package with an older fleetd

- **Started:** 2026-10-27T10:24:41Z
- **Objective:** Build the bypass package with fleetd (orbit and Fleet Desktop) 1.58.0, set up a fresh VM with it, reset it, then set fleet 10 update_channels to stable
- **Expected:** fleetd comes back at 1.58.0 after the reset; it updates only when Fleet sets update_channels

## Steps and evidence
- `01-build-msi-1.58.0.txt`: `OLD=1.58.0 tools/build-msis.sh arm64`
- `002-builder-in-utm.png` (window screenshot: UTM / ppkg-builder)

The v1 builder VM (ppkg-builder) no longer boots: Automatic Repair on QEMU, "Display output is not active" with no guest agent in UTM (002). A new builder (builder2) is a QEMU overlay of the golden image, left at the region screen, with the ADK installed as in S-4.
- `02-builder2-adk-install.txt`: `tools/qga.sh builder2 'New-Item -ItemType Directory -Force C:\build | Out-Null; Invoke-WebRequest -UseBasicPar`

Stopped here on request, after the MSI with fleetd 1.58.0 was built (01, SHA-256 AF6295CC...) and copied into builder2 with the package XML (ppkg/customizations-b-1.58.0.xml). The package was not built and no VM was reset. From fleetd's code at fleet-v4.93.0 (orbit/cmd/orbit/orbit.go, serverOverridesRunner): a package built with --orbit-channel pins fleetd to that version, and Fleet changes it only if the fleet's agent options set update_channels; fleet 10 sets none. A package built on the stable channel follows stable and updates itself.

## Result: NOT-RUN

Stopped after building the fleetd 1.58.0 MSI; the package wasn't built. From code, a version-pinned package keeps that fleetd until the fleet sets update_channels

_Finished 2026-10-27T11:08:57Z_
