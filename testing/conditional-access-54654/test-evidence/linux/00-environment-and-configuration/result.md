# 00: Environment and configuration

- **Started:** 2026-10-07T18:06:36Z
- **Objective:** Record exactly what was tested: versions, hosts, and sanitized configuration.
- **Expected:** A reader can recreate the lab.

## Steps and evidence
- `01-mac.txt`: `sw_vers; uname -m; docker --version; fleetctl --version 2>&1 | head -1; step version 2>&1 | head -1`
- `02-services.txt`: `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'; docker exec stepca step-ca version 2>&1 | head`
- `03-fleet-server.txt`: `curl -s -H "Authorization: Bearer $FLEET_TOKEN_DUO" $FLEET_URL/api/v1/fleet/version | jq -c '{version,go_versi`
- `04-fleet-host.txt`: `fleetctl api '/hosts/identifier/86d7dc8e-3373-47af-86dd-56a1cd517e2f' 2>/dev/null | jq '.host|{id,uuid,hostnam`
- `05-vm.txt` (VM): `uname -a; lsb_release -ds; cat /sys/class/dmi/id/product_uuid; cat /etc/machine-id; systemctl is-active orbit `
- `06-vm-duo-emulation.txt` (VM): `cat /etc/systemd/system/duo-desktop.service.d/emulation.conf; /usr/local/bin/qemu-x86_64-10 --version | head -`
- `07-stepca-config.txt`: `python3 -c "
import json
c=json.load(open('stepca/data/config/ca.json'))
out={'dnsNames':c.get('dnsNames'),'provisioners':[]}
for p in c['authority']['provisioners']:
    q={k:v for k,v in p.items() if k not in ('key','encryptedKey','decrypterKey','challenge','options')}
    q['challenge']='<removed>' if 'challenge' in p else None
    q['x509 template']='see 08-stepca-template.txt' if 'options' in p else None
    out['provisioners'].append(q)
print(json.dumps(out,indent=1))"`
- `08-stepca-template.txt`: `cat stepca/data/templates/scep-client.tpl`

## Result: INFO

How the lab was set up. Not a test.
