# X-6: End user authentication off on the fleet

- **Started:** 2026-10-27T09:03:10Z
- **Objective:** Host 29 (c4 VM, MSI-enrolled brownfield). Stage the no-bypass package from Fleet, turn fleet 10 end user authentication off through the API, wipe, delete the host after the device acknowledges, then restore the GitOps setting
- **Expected:** With authentication off, the reset host enrolls as a new host with no sign-in and no IdP user

## Steps and evidence
- `01-host-29-to-fleet-10.txt`: `python3 -I tools/fleet-post.py /api/v1/fleet/hosts/transfer '{"team_id":10,"hosts":[29]}'`

- `08-usb-plug-removable.txt`: `tools/qmp.sh c4 usb out/usb-pkg-n-pla`
- `09-fleet-copy-from-usb.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path payloads/local/copy-ppkg-from-us`

- `13-fleet-stage-ppkg.txt`: `fleetctl run-script --host 1FCA0238-3AEF-4D8E-9574-3E800F01701E --script-path scripts/stage-ppkg.ps1 2>&1 | gr`

The no-bypass package was copied from a USB drive by a Fleet script (09) and staged by scripts/stage-ppkg.ps1 (13): SHA-256 C137DC24... in C:\Recovery\Customizations, which only SYSTEM and Administrators can read.

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

Timeline (UTC): end user authentication off on fleet 10 at 09:20:01, wipe sent 09:20:02, acknowledged 09:20:33, host 29 deleted 09:20:34. Fleet created host 30 at 09:36:05 for the same UUID, fleetd enrolled 09:36:07 at the region screen with no prompt and no sign-in, MDM On by 09:37 (host-30-after, fleet-poll.log, 18). No end user. 15.5 minutes from acknowledgment. The no-bypass package came back from C:\Recovery\Customizations (live-query-after). End user authentication is back on (eua-restored). So the no-bypass build only asks for sign-in when the fleet requires it; with it off, a deleted host comes back as a new host with no user, like the bypass build.

## Result: PASS

With end user authentication off, the reset no-bypass host enrolled as a new host (host 30) with no prompt and no end user, MDM on, 15.5 minutes after the wipe

_Finished 2026-10-27T09:37:38Z_
- `024-fleet-host-30-captured-later.jpg` (Fleet UI, Chrome; captured at 11:4x UTC after the VM was shut down, so Offline: new host 30 in fleet 10, no IdP user, only "MDM turned on" in its feed)
