. evidence/lib.sh
ev_note D-8 "### Recovery: the real list is back, sign in again"
ev_cmd D-8 list-is-restored "grep 'linux:' duo/sync.log | tail -2; echo; cat duo/run/linux.csv" >/dev/null
ev_vm D-8 recovered-launch "bash /tmp/br2.sh" >/dev/null; sleep 12
utm_type "lab-test" >/dev/null; utm_codes "15, 143" >/dev/null; utm_type "x" >/dev/null; utm_codes "28, 156" >/dev/null; sleep 20
utm_click 733 241 >/dev/null; sleep 28; ev_shot D-8 recovered-1-after-local-network-allow >/dev/null
utm_click 673 449 >/dev/null; sleep 6
utm_type "$DUO_BYPASS_SECRET" >/dev/null; utm_codes "28, 156" >/dev/null; sleep 22
utm_click 673 526 >/dev/null; sleep 22; utm_codes "224, 79, 224, 207" >/dev/null; sleep 3; ev_shot D-8 recovered-2-auth-response-bottom >/dev/null
