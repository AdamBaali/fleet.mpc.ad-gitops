. evidence/lib.sh
ev_init 00 "Environment and configuration" "Record exactly what was tested: versions, hosts, and sanitized configuration." "A reader can recreate the lab." >/dev/null
ev_cmd 00 mac "sw_vers; uname -m; docker --version; fleetctl --version 2>&1 | head -1; step version 2>&1 | head -1" >/dev/null
ev_cmd 00 services "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'; docker exec stepca step-ca version 2>&1 | head -1; curl -sk -u Administrator:\$PING_ADMIN_PASSWORD -H 'X-XSRF-Header: PingFederate' https://localhost:9999/pf-admin-api/v1/version" >/dev/null
ev_cmd 00 fleet-server "curl -s -H \"Authorization: Bearer \$FLEET_TOKEN_DUO\" \$FLEET_URL/api/v1/fleet/version | jq -c '{version,go_version}'; fleetctl api /config 2>/dev/null | jq -c '{license:.license.tier, org:.org_info.org_name, expires:.license.expiration, device_limit:.license.device_limit}'" >/dev/null
ev_cmd 00 fleet-host "fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '.host|{id,uuid,hostname,platform,os_version,osquery_version,orbit_version,team_name,status,policies:[.policies[]|{name,critical,response}]}'" >/dev/null
ev_vm 00 vm "uname -a; lsb_release -ds; cat /sys/class/dmi/id/product_uuid; cat /etc/machine-id; systemctl is-active orbit duo-desktop tpm2-abrmd; ls /dev/tpm0 /dev/tpmrm0; snap list firefox chromium 2>/dev/null | tail -2; dpkg -l duo-desktop | tail -1 | cut -c1-80" >/dev/null
ev_vm 00 vm-duo-emulation "cat /etc/systemd/system/duo-desktop.service.d/emulation.conf; /usr/local/bin/qemu-x86_64-10 --version | head -1" >/dev/null
ev_cmd 00 stepca-config "python3 -c \"
import json
c=json.load(open('stepca/data/config/ca.json'))
out={'dnsNames':c.get('dnsNames'),'provisioners':[]}
for p in c['authority']['provisioners']:
    q={k:v for k,v in p.items() if k not in ('key','encryptedKey','decrypterKey','challenge','options')}
    q['challenge']='<removed>' if 'challenge' in p else None
    q['x509 template']='see 08-stepca-template.txt' if 'options' in p else None
    out['provisioners'].append(q)
print(json.dumps(out,indent=1))\"" >/dev/null
ev_cmd 00 stepca-template "cat stepca/data/templates/scep-client.tpl" >/dev/null
