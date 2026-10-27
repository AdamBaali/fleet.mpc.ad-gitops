# E-1r: PKG-B at the region screen, generalized image

- **Started:** 2026-10-26T18:29:48Z
- **Objective:** Rerun E-1 on a clone of the sysprep-generalized golden image
- **Expected:** Same as E-1, with a unique machine identity

## Steps and evidence
- `01-delete-old-hosts.txt`: `fleetctl api -X DELETE /api/v1/fleet/hosts/21 2>&1 | tail -1; fleetctl api -X DELETE /api/v1/fleet/hosts/22 2>`
- `02-clone.txt`: `vm/clone.sh new ppkg-golden-gen e1b-bypass && vm/attach-usb.sh e1b-bypass out/usb-pkg-b-plain.img >/dev/null &`
- `03-identity.txt`: `tools/vm-exec.sh e1b-bypass '"MachineGuid: " + (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Cryptography).Machin`
- `04-region-screen.png` (window screenshot: UTM / e1b-bypass)

The sysprep /generalize /oobe clone of the golden image (ppkg-golden-gen) hung at the UEFI Start boot option screen for over 15 minutes and never reached Windows (04). Not pursued. Instead each host lineage runs in sequence: E-1 then its W tests, then E-2 then its W tests, so only one clone holds the shared Windows MDM hardware ID at a time.

## Result: INFO

Generalized image does not boot in UTM on arm64; switched to running host lineages one after another.

_Finished 2026-10-26T18:46:26Z_
