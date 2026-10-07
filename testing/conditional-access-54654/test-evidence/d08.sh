. evidence/lib.sh
UUID=86d7dc8e-3373-47af-86dd-56a1cd517e2f
ev_init D-8 "Linux host removed from Duo's list is blocked" "When the host is no longer in the list Duo holds, the same sign-in that worked in D-5 is blocked. The host returns after the next sync." "Duo shows 'Device not allowed'." >/dev/null
# wait for a fresh loop run so the window before the next overwrite is as long as possible
last=$(grep 'linux:' duo/sync.log | tail -1 | awk '{print $1}')
ev_cmd D-8 wait-for-sync-cycle "echo 'last Linux sync before waiting:' $last; for i in \$(seq 1 70); do n=\$(grep 'linux:' duo/sync.log | tail -1 | awk '{print \$1}'); [ \"\$n\" != '$last' ] && { echo \"new cycle finished at \$n\"; break; }; sleep 5; done" >/dev/null
printf 'device_id\n00000000-0000-4000-8000-000000000002\n' > $TMPDIR/linux-placeholder.csv
ev_cmd D-8 remove-host-from-list "echo 'Uploading a list that does NOT contain $UUID (a placeholder ID keeps the list non-empty, because Duo refuses an empty one):'; cat $TMPDIR/linux-placeholder.csv; echo; python3 evidence/duo-upload.py linux $TMPDIR/linux-placeholder.csv" >/dev/null
ev_vm D-8 launch "bash /tmp/br2.sh" >/dev/null; sleep 12; ev_shot D-8 1-login-page >/dev/null
utm_type "lab-test" >/dev/null; utm_codes "15, 143" >/dev/null; utm_type "x" >/dev/null; utm_codes "28, 156" >/dev/null; sleep 20
ev_shot D-8 2-after-login >/dev/null
utm_click 733 241 >/dev/null; sleep 25; ev_shot D-8 3-result-device-not-allowed >/dev/null
ev_cmd D-8 restore-list "echo 'Restoring the real list (the 5-minute loop would also do this):'; cat duo/run/linux.csv; echo; python3 evidence/duo-upload.py linux duo/run/linux.csv" >/dev/null
ev_vm D-8 close-browser "bash /tmp/killbr.sh" >/dev/null
unlink $TMPDIR/linux-placeholder.csv
