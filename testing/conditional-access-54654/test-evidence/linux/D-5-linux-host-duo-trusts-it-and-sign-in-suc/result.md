# D-5: Linux host: Duo trusts it and sign-in succeeds

- **Started:** 2026-10-07T18:45:13Z
- **Objective:** With the Linux integration active for the test group and the host in the synced list, a sign-in from the host (browser plus Duo Desktop) is allowed.
- **Expected:** Duo shows no 'Device not allowed'; the Auth Response reports the endpoint as trusted via Duo Desktop.

## Steps and evidence
- `01-starting-point.txt` (VM): `echo 'device ids on this host:'; echo " product_uuid: $(cat /sys/class/dmi/id/product_uuid)"; echo " machine-i`
- `02-id-in-fleet-and-csv.txt`: `echo 'Fleet host uuid:'; fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | j`
- `03-launch.txt` (VM): `bash /tmp/br2.sh`
- `04-1-login-page.png` (VM screenshot)
- `05-2-after-login.png` (VM screenshot)
- `06-3-after-local-network-allow.png` (VM screenshot)
- `07-4-bypass-code-screen.png` (VM screenshot)
- `08-5-is-this-your-device.png` (VM screenshot)
- `09-6-auth-response-top.png` (VM screenshot)
- `10-7-auth-response-bottom.png` (VM screenshot)
- `11-demo-app-log.txt`: `echo 'Demo app log (callback from the VM at 192.168.64.x):'; grep duo-callback duo/demo.log | tail -2 | sed -E`
- `09-6-auth-response-top.png` is cropped above the `ip` field (it holds the lab's public IP); the uncropped original is kept privately.

## Result: **PASS**

From the Linux VM (Firefox 157 plus Duo Desktop 4.7.0 under emulation) the sign-in to the Duo demo ended with trusted_endpoint_status trusted, auth_result allow (Login Successful), device_info_source duo_desktop, endpoint EPBXQCG5T0RRF1PNK3QE. The second factor was a bypass code (the test user's only enrolled factor is Touch ID on the Mac). The browser asked for the local-network permission first. See 06-3-after-local-network-allow.png and 10-7-auth-response-bottom.png.

_Finished 2026-10-07T18:49:07Z_
