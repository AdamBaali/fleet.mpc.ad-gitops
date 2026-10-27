# C-5: Cloud reprovision reset

- **Started:** 2026-10-27T04:11:04Z
- **Objective:** Host 29 after C-4 (bypass package in C:\Recovery\Customizations, MDM on). Send doWipeCloudPersistProvisionedData from Fleet
- **Expected:** Windows downloads a fresh image, then as C-1: same host back with MDM on, no prompt. Record download time and disk use

## Steps and evidence
- `03-wipe-command.txt`: `fleetctl mdm run-command --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --payload payloads/doWipeCloudPersistPro`
- `05-wipe-result.txt`: `fleetctl get mdm-command-results --id=f437314e-91ba-464d-91ab-20d0e8586fc8`
- `06-live-query-after.txt`: `fleetctl query --hosts 1FCA0238-3AEF-4D8E-9574-3E800F01701E --exit --timeout 90s --query "$(cat queries/after-`
- `07-wipe-result-retry.txt`: `fleetctl get mdm-command-results --id=f437314e-91ba-464d-91ab-20d0e8586fc8`
- `08-c4-wipe-result-compare.txt`: `fleetctl get mdm-command-results --id=7a972475-5cc1-4cf2-8870-1ac5a13c0de8`
- `009-fleet-host-after.jpg` (Fleet UI, Chrome)

Timeline (UTC): cloud wipe sent 04:11:07, device status 101 (in progress) while it downloaded; Windows stayed on the region screen and the VM disk grew from 6.9 to 31 GiB. Host offline 04:47:23 (about 36 min of download), Resetting this PC from about 04:48 (watch/), fleetd re-enrolled 05:08:18 as the same host 29, MDM On 05:09:35 (mdm_enrolled 05:09:19). 57 minutes in total, no prompt. Disk after: 38 GiB allocated in the VM image (03).

Live query at the region screen (live-query-after): fleetd RUNNING, staged fleet-agent.ppkg and InstallOrder.ini still in C:\Recovery\Customizations, built-in local users only, 0 markers. The cloud image reset re-applied the staged package like the local one.

API finding (A-2): after the host re-enrolled, fleetctl get mdm-command-results fails for this command with converting NULL to string is unsupported (wipe-result, wipe-result-retry). Every wipe command in this run now fails the same way (C-1 to C-4), though C-1 returned status 200 at 00:38, before Windows MDM re-enrolled. GetMDMWindowsCommandResults (server/datastore/mysql/microsoft_mdm.go:1840 at fleet-v4.93.0) selects mwe.host_uuid through a LEFT JOIN on mdm_windows_enrollments by the enrollment id that ran the command; after re-enrollment (or host deletion) that row is gone, host_uuid is NULL, and the scan into a string fails the whole request.

## Result: PASS

Cloud variant works: doWipeCloudPersistProvisionedData downloaded an image for about 36 min, reset, and the same Fleet host came back with MDM on and no prompt, 57 min in total. Its command result can no longer be read once the host re-enrolls (Fleet bug, all wipe commands).

_Finished 2026-10-27T05:14:05Z_
