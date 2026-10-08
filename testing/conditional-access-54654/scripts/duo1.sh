. evidence/lib.sh
UUID=86d7dc8e-3373-47af-86dd-56a1cd517e2f
# D-1
ev_init D-1 "Duo Desktop for Linux installed and running" "Duo Desktop 4.7.0 runs on the Linux host. (Lab: x86-64 package under user-mode emulation on an ARM VM; Duo documents ARM Linux as unsupported. Installed by hand with dpkg, not by a Fleet custom package.)" "The duo-desktop service is active and listening on 53100 (HTTPS) and 53106 (HTTP)." >/dev/null
ev_vm D-1 package-and-service "dpkg -l duo-desktop | tail -1 | cut -c1-90; systemctl is-active duo-desktop; systemctl show duo-desktop -p NRestarts -p ActiveEnterTimestamp | tr '\n' ' '; echo; ss -ltn 2>/dev/null | grep -E ':(53100|53106)' | head -4" >/dev/null
ev_vm D-1 emulation-dropin "cat /etc/systemd/system/duo-desktop.service.d/emulation.conf; echo; /usr/local/bin/qemu-x86_64-10 --version | head -1; file /opt/duo/duo-desktop/duo-desktop | cut -c1-120" >/dev/null
ev_vm D-1 https-answers "curl -sk -m 10 -o /dev/null -w 'https://localhost:53100/ -> %{http_code}\n' https://localhost:53100/; curl -s -m 10 -o /dev/null -w 'http://localhost:53106/ -> %{http_code}\n' http://localhost:53106/" >/dev/null
ev_vm D-1 duo-desktop-log "tail -14 /var/log/duo-desktop/duo-desktop.log | cut -c1-230" >/dev/null
ev_verdict D-1 PARTIAL "Duo Desktop 4.7.0 (amd64 package from Duo's download link) is installed and its service is active, answering on HTTPS 53100 and HTTP 53106. It needed lab workarounds because the VM is ARM: amd64 multiarch, x86 libraries, QEMU 10 user-mode emulation, DOTNET_EnableWriteXorExecute=0. A Fleet-driven install of the custom package and a real x86-64 host were not tested."
# D-3
ev_init D-3 "Export script writes the three CSVs" "The guide's export script (with the PR fixes) writes macos.csv, windows.csv and linux.csv with a device_id header." "Header plus one UUID per Fleet host for macOS and Linux; Windows has no hosts." >/dev/null
ev_cmd D-3 run-export "W=\$(mktemp -d); sed -e 's#https://fleet.example.com#https://fleet.mpc.ad#' -e 's#<Windows-MachineGuid-report-ID>#69#' fleet/docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh > \$W/export.sh; cd \$W; FLEET_API_TOKEN=\$FLEET_TOKEN_DUO bash export.sh; echo; echo 'files:'; ls -A; for f in macos windows linux; do echo \"== \$f.csv\"; cat \$f.csv; done" >/dev/null
ev_cmd D-3 script-version "git -C fleet log --oneline -1 -- docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh | cat; shellcheck fleet/docs/solutions/api-scripts/export-fleet-hosts-for-duo.sh && echo 'shellcheck: clean'" >/dev/null
ev_verdict D-3 PASS "The export (guide script plus temp-file and shrink-guard fix) wrote macos.csv and linux.csv with one UUID each and header-only windows.csv; no temp folder was left behind."
# D-4
ev_init D-4 "Duo sync uploads the Linux list" "Duo's device_cache_sync.py (keyless copy reading its keys from environment variables) creates a cache, uploads the CSV, and activates it." "Devices synced: 1." >/dev/null
ev_cmd D-4 sync-script-no-secrets "echo 'The script file in the GitOps repo holds no keys:'; grep -c -E \"API_SKEY.*[A-Za-z0-9]{30}\" <gitops-repo>/duo/device_cache_sync.py | sed 's/^/lines with a hard-coded secret key: /'; sed -n '/^import os/,/^}/p' <gitops-repo>/duo/device_cache_sync.py | head -12" >/dev/null
ev_cmd D-4 linux-sync-dry-run "python3 - <<'P'
import re,os,subprocess
t=open('secrets/duo/linux/device_cache_sync.py').read()
blk=re.search(r\"MKEY_CREDENTIALS = \\{\\n.*?\\n\\}\\n\",t,re.S).group(0)
env=dict(os.environ,DUO_MKEY=re.search(r\"'(DM[A-Z0-9]{18})'\",blk).group(1),DUO_IKEY=re.search(r\"'API_IKEY'\\s*:\\s*'([^']+)'\",blk).group(1),DUO_SKEY=re.search(r\"'API_SKEY'\\s*:\\s*'([^']+)'\",blk).group(1),DUO_API_HOST=re.search(r\"'API_HOST'\\s*:\\s*'([^']+)'\",blk).group(1))
csv='/tmp/linux-ev.csv'; open(csv,'w').write('device_id\n$UUID\n')
r=subprocess.run(['.venv/bin/python','<gitops-repo>/duo/device_cache_sync.py','--infile',csv,'--device_id_column','device_id','--dry_run'],env=env,capture_output=True,text=True)
o=(r.stdout+r.stderr)
for k in ('DUO_SKEY','DUO_IKEY','DUO_MKEY'): o=o.replace(env[k],'<'+k.lower()+'>')
print('(--dry_run: uploads the list, then deletes the new cache instead of activating it)'); print(o); print('exit',r.returncode)
P" >/dev/null
ev_cmd D-4 sync-loop-log "echo 'Real syncs by the 5-minute loop (duo/sync.log), last 12 lines:'; tail -12 duo/sync.log" >/dev/null
ev_verdict D-4 PASS "The keyless script created a cache, uploaded the Linux UUID and (in dry-run) discarded it; the 5-minute loop shows real runs with 'linux: 1 synced'. The script holds no keys; they come from environment variables."
