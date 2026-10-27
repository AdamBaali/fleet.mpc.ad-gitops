# X-5: Package with an older fleetd

- **Started:** 2026-10-27T09:40:44Z
- **Objective:** Build the package with an older fleetd, then C-1
- **Expected:** fleetd comes back old, then updates itself

## Steps and evidence

Not run. It needs a new MSI (fleetctl package with an older --orbit-channel) and a new package built with ICD on the builder VM in UTM, then a fresh VM. About 1.5 hours. The reset re-applies whatever the package holds (C-1 to C-5 show the package's fleetd 1.62.1 each time), so the open question is only how fast fleetd updates itself afterwards.

## Result: NOT-RUN

Needs a package rebuilt with an older fleetd on the builder VM

_Finished 2026-10-27T09:40:44Z_
