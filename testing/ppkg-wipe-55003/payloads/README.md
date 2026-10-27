# Wipe payloads

`library/` holds the four commands as Fleet's MDM command library publishes them (`docs/mdm-commands.yml` at
`fleet-v4.93.0`), wrapped in `<syncml><syncbody>`. Fleet's own `fleetctl mdm run-command` rejects that form with
"You can run only <Exec> command type." (`server/fleet/microsoft_mdm.go`, `ParseWindowsMDMCommand`). The files in this
folder are the same commands unwrapped to the top-level `<Exec>` element, which Fleet accepts.

`local/` holds lab-only PowerShell, run through the VM's guest agent or as a Fleet script:

| File | What it does |
|---|---|
| `wipe-persist-local.ps1` | Calls `doWipePersistProvisionedData` locally through the MDM WMI bridge, with no Fleet (L-3) |
| `install-msi.ps1` | Installs fleetd from an MSI copied to `C:\Windows\Temp`, as a brownfield host has it (C-4) |
| `markers.ps1` | Writes marker files, so a reset has user data to remove |
| `copy-ppkg-from-usb.ps1` | Copies the package from a USB drive to `C:\Windows\Temp` for `scripts/stage-ppkg.ps1` (X-6) |
| `list-packages.ps1` | Lists every package a reset could re-apply (X-7) |
| `remove-kept-ppkg.ps1` | Removes the kept package, so no package is left (X-7) |
