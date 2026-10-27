# X-6: End user authentication off on the fleet

- **Started:** 2026-10-27T09:03:10Z
- **Objective:** Host 29 (c4 VM, MSI-enrolled brownfield). Stage the no-bypass package from Fleet, turn fleet 10 end user authentication off through the API, wipe, delete the host after the device acknowledges, then restore the GitOps setting
- **Expected:** With authentication off, the reset host enrolls as a new host with no sign-in and no IdP user

## Steps and evidence
- `01-host-29-to-fleet-10.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/transfer '{"team_id":10,"hosts":[29]}'`
- `02-usb-hot-plug.txt`: `tools/qmp.sh c4 usb /Users/adam/Documents/GitHub/fleet.mpc.ad-gitops/testing/ppkg-wipe-55003/out/usb-pkg-n-pla`
- `03-fleet-copy-from-usb.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path payloads/local/copy-ppkg-from-us`
- `04-fleet-stage-ppkg.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path scripts/stage-ppkg.ps1 2>&1 | gr`

The first hot-plug as a fixed disk did not show up in Windows (no disk 1, so the copy script failed; 03, 04). Re-plugged as removable: Windows mounted it as D: (PPKG).
- `05-usb-replug-removable.txt`: `tools/qmp.sh c4 unusb; sleep 3; tools/qmp.sh c4 '{"execute":"blockdev-del","arguments":{"node-name":"usbimg"}}`
- `06-fleet-copy-from-usb.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path payloads/local/copy-ppkg-from-us`
- `07-fleet-stage-ppkg.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path scripts/stage-ppkg.ps1 2>&1 | gr`

Steps 05 to 07: the recording step (05) re-ran the unplug by mistake, so 06 and 07 failed again with no drive. Plugged back in as removable (08).
- `08-usb-plug-removable.txt`: `tools/qmp.sh c4 usb /Users/adam/Documents/GitHub/fleet.mpc.ad-gitops/testing/ppkg-wipe-55003/out/usb-pkg-n-pla`
- `09-fleet-copy-from-usb.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path payloads/local/copy-ppkg-from-us`
- `10-fleet-stage-ppkg.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path scripts/stage-ppkg.ps1 2>&1 | gr`

Staging the no-bypass package failed (10): Windows holds C:\Recovery\Customizations\fleet-agent.ppkg open while the host sits at the setup screen after a reset, so the script can't replace it. No process command line names it (diag). Restarting Windows at the region screen to release it.
- `11-restart-at-region-screen.txt`: `tools/qmp.sh c4 '{"execute":"system_reset"}'`
- `12-setup-applied-usb-package-0x800700b7.png` (VM screen after the restart with the USB drive in)
- `13-fleet-stage-ppkg-after-restart.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path scripts/stage-ppkg.ps1 2>&1 | gr`
- `14-setup-oobeprovisioningentry.png` (VM screen after dismissing the failure)

The restart with the USB drive still in made Windows setup apply the no-bypass package by itself, which failed with 0x800700b7 (12), then "Something went wrong, OOBEPROVISIONINGENTRY" (14, Try again pressed). 0x800700b7 is ERROR_ALREADY_EXISTS: fleetd was already installed. After that the stage script ran (13): the no-bypass package (SHA-256 C137DC24...) replaced the bypass one in C:\Recovery\Customizations.
- `15-eua-before.txt`: `fleetctl api /api/v1/fleet/teams/10 2>/dev/null | python3 -c 'import sys,json; print("enable_end_user_authenti`
- `16-eua-off.txt`: `METHOD=PATCH python3 -I tools/fleet-post.py /api/v1/fleet/setup_experience '{"team_id":10,"enable_end_user_aut`
- `17-wipe-command.txt`: `fleetctl mdm run-command --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --payload payloads/doWipePersistProvisio`
- `18-command-acknowledged.txt`: `fleetctl get mdm-command-results --id=89dd5d52-c7b3-4a24-a2ae-e783d37c91b8 2>&1 | grep -v -i version | sed "s#`
- `19-delete-host-29.txt`: `fleetctl api -X DELETE /api/v1/fleet/hosts/29 2>&1 | grep -v -i version; fleetctl api /api/v1/fleet/hosts/29 2`
- host 29 deleted at 09:20:34; GET /hosts/29 now returns 404
- `18-vm-screen-after.png` (VM screen after enrollment)
- `21-host-30-after.txt`: `fleetctl api /api/v1/fleet/hosts/30 2>/dev/null | python3 -c 'import sys,json; h=json.load(sys.stdin)["host"];`
- `22-live-query-after.txt`: `fleetctl query --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --exit --timeout 90s --query "$(cat queries/after-`
- `23-eua-restored.txt`: `METHOD=PATCH python3 -I tools/fleet-post.py /api/v1/fleet/setup_experience '{"team_id":10,"enable_end_user_aut`

Timeline (UTC): end user authentication off on fleet 10 at 09:20:01, wipe sent 09:20:02, acknowledged 09:20:33, host 29 deleted 09:20:34. Fleet created host 30 at 09:36:05 for the same UUID, fleetd enrolled 09:36:07 at the region screen with no prompt and no sign-in, MDM On by 09:37 (host-30-after, fleet-poll.log, 18). No end user. 15.5 minutes from acknowledgment. The no-bypass package came back from two places: staged in C:\Recovery\Customizations and kept in ProgramData from the auto-apply at 12 (live-query-after). End user authentication is back on (eua-restored). So the no-bypass build only asks for sign-in when the fleet requires it; with it off, a deleted host comes back as a new host with no user, like the bypass build.

## Result: PASS

With end user authentication off, the reset no-bypass host enrolled as a new host (host 30) with no prompt and no end user, MDM on, 15.5 minutes after the wipe

_Finished 2026-10-27T09:37:38Z_
