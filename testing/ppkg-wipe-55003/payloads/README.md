# Wipe payloads

`library/` holds the four commands as Fleet's MDM command library publishes them (`docs/mdm-commands.yml` at
`fleet-v4.93.0`), wrapped in `<syncml><syncbody>`. Fleet's own `fleetctl mdm run-command` rejects that form with
"You can run only <Exec> command type." (`server/fleet/microsoft_mdm.go`, `ParseWindowsMDMCommand`). The files in this
folder are the same commands unwrapped to the top-level `<Exec>` element, which Fleet accepts.
