. evidence/lib.sh
UUID=86d7dc8e-3373-47af-86dd-56a1cd517e2f
ev_init D-5 "Linux host: Duo trusts it and sign-in succeeds" "With the Linux integration active for the test group and the host in the synced list, a sign-in from the host (browser plus Duo Desktop) is allowed." "Duo shows no 'Device not allowed'; the Auth Response reports the endpoint as trusted via Duo Desktop." >/dev/null
ev_vm D-5 starting-point "echo 'device ids on this host:'; echo \" product_uuid: \$(cat /sys/class/dmi/id/product_uuid)\"; echo \" machine-id : \$(cat /etc/machine-id)\"; echo \"duo-desktop: \$(systemctl is-active duo-desktop)\"" >/dev/null
ev_cmd D-5 id-in-fleet-and-csv "echo 'Fleet host uuid:'; fleetctl api '/hosts/identifier/$UUID' 2>/dev/null | jq -r .host.uuid; echo 'linux.csv sent to Duo:'; cat duo/run/linux.csv" >/dev/null
ev_vm D-5 launch "bash /tmp/br2.sh" >/dev/null; sleep 14; ev_shot D-5 1-login-page >/dev/null
utm_type "lab-test" >/dev/null; utm_codes "15, 143" >/dev/null; utm_type "x" >/dev/null; utm_codes "28, 156" >/dev/null; sleep 22
ev_shot D-5 2-after-login >/dev/null
utm_click 733 241 >/dev/null; sleep 30; ev_shot D-5 3-after-local-network-allow >/dev/null
utm_click 673 449 >/dev/null; sleep 6; ev_shot D-5 4-bypass-code-screen >/dev/null
utm_type "$DUO_BYPASS_SECRET" >/dev/null; utm_codes "28, 156" >/dev/null; sleep 22; ev_shot D-5 5-is-this-your-device >/dev/null
utm_click 673 526 >/dev/null; sleep 22; ev_shot D-5 6-auth-response-top >/dev/null
utm_codes "224, 79, 224, 207" >/dev/null; sleep 3; ev_shot D-5 7-auth-response-bottom >/dev/null
ev_cmd D-5 demo-app-log "echo 'Demo app log (callback from the VM at 192.168.64.x):'; grep duo-callback duo/demo.log | tail -2 | sed -E 's/(state|duo_code)=[^& ]+/\\1=<x>/g'" >/dev/null
