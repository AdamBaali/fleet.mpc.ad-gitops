# D-8: Linux host removed from Duo's list is blocked

- **Started:** 2026-10-07T18:49:24Z
- **Objective:** When the host is no longer in the list Duo holds, the same sign-in that worked in D-5 is blocked. The host returns after the next sync.
- **Expected:** Duo shows 'Device not allowed'.

## Steps and evidence
- `01-wait-for-sync-cycle.txt`: `echo 'last Linux sync before waiting:' 2026-10-07T18:44:53Z; for i in $(seq 1 70); do n=$(grep 'linux:' duo/sy`
- `02-remove-host-from-list.txt`: `echo 'Uploading a list that does NOT contain 86d7dc8e-3373-47af-86dd-56a1cd517e2f (a placeholder ID keeps the `
- `03-launch.txt` (VM): `bash /tmp/br2.sh`
- `04-1-login-page.png` (VM screenshot)
- `05-2-after-login.png` (VM screenshot)
- `06-3-result-device-not-allowed.png` (VM screenshot)
- `07-restore-list.txt`: `echo 'Restoring the real list (the 5-minute loop would also do this):'; cat duo/run/linux.csv; echo; python3 e`
- `08-close-browser.txt` (VM): `bash /tmp/killbr.sh`

### Recovery: the real list is back, sign in again
- `09-list-is-restored.txt`: `grep 'linux:' duo/sync.log | tail -2; echo; cat duo/run/linux.csv`
- `10-recovered-launch.txt` (VM): `bash /tmp/br2.sh`
- `11-recovered-1-after-local-network-allow.png` (VM screenshot)
- `12-recovered-2-auth-response-bottom.png` (VM screenshot)

## Result: **PASS**

With this Linux VM removed from the list Duo holds (a placeholder ID kept the list non-empty), the same sign-in as D-5 was stopped at Device not allowed (Event ID AXYXQ8VGBFW9YPOLHDRP; Duo log 18:50:58 Denied, Endpoint is not trusted, Not a Trusted Endpoint determined by Duo Desktop; endpoint record Trusted: No). After the real list was restored and the user signed in again (18:53:28) Duo allowed it and the endpoint returned to Trusted: Yes. This proves the Duo side; Fleet driving the removal through a failing critical policy needs REQUIRE_PASSING_CRITICAL_POLICIES plus a second healthy host (not run).

_Finished 2026-10-07T18:54:45Z_
