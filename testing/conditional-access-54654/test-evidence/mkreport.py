import os,re,glob,datetime
EV='evidence/linux'
rows={}
for l in open(f'{EV}/results.tsv'):
    p=l.rstrip('\n').split('\t')
    if len(p)>=4: rows[p[0]]=p
order=['P-5','P-3','P-4','P-6','P-6b','P-7','P-8','P-9','P-10','P-11','P-12','P-13','P-14','P-15','D-1','D-3','D-4','D-5','L-1','D-6','D-8','D-9','D-10','D-12']
def title(d):
    t=open(f'{EV}/{d}/result.md').readline().strip('# \n')
    return t.split(':',1)[1].strip() if ':' in t else t
def one(note,n=230):
    note=re.sub(r'\s+',' ',note).strip()
    return note if len(note)<=n else note[:n].rsplit(' ',1)[0]+'…'
icon={'PASS':'PASS','PARTIAL':'PARTIAL','FAIL':'FAIL'}
out=[]
out.append('# Conditional access guides (PingFederate and Duo): Linux test report\n')
out.append('Test of the guides and scripts in [fleetdm/fleet#54346](https://github.com/fleetdm/fleet/pull/54346) for [#54654](https://github.com/fleetdm/fleet/issues/54654). Linux run from scratch on 2026-10-07, with evidence for every test.\n')
out.append('| | |\n|---|---|')
out.append('| **Lab Fleet** | Fleet 4.92.3 Premium (`fleet.mpc.ad`), fleet "Ping Duo Lab", everything applied through GitOps |')
out.append('| **PingFederate** | 13.1.3 in Docker, X.509 Certificate IdP Adapter 1.3.2, secondary HTTPS port 9032 |')
out.append('| **CA** | Smallstep step-ca 0.30.2 with a SCEP provisioner behind a Cloudflare Tunnel (used by the Mac); Linux certificates issued directly |')
out.append('| **Duo** | Trial account, three Generic Trusted Endpoints integrations (Linux and macOS active for group `fleet-lab`), Web SDK demo app |')
out.append('| **Linux host** | Ubuntu 24.04 arm64 VM (UTM), Firefox 157 (deb and snap), Chromium 154 (snap), fleetd, Duo Desktop 4.7.0 (x86-64 package under emulation, see caveats) |')
out.append('| **Evidence** | Per-test folders below: raw command output with timestamps, screenshots taken inside the VM, sanitized configuration. Tokens, keys and the lab\'s public IP are redacted. |\n')
c={k:sum(1 for r in rows.values() if r[1]==k) for k in ('PASS','PARTIAL','FAIL')}
out.append(f'**Result: {c["PASS"]} passed, {c["PARTIAL"]} partial, {c["FAIL"]} failed.**\n')
out.append('## Results\n')
out.append('| ID | Test | Result | What it showed | Evidence |\n|---|---|---|---|---|')
for i in order:
    if i not in rows: continue
    r=rows[i]; d=r[2]
    out.append(f'| {i} | {title(d)} | **{r[1]}** | {one(r[3])} | [{d.split("-")[0]}-{d.split("-")[1] if d.split("-")[1].isdigit() else ""}…]({d}/result.md) |')
out.append('\n_Configuration as tested: [CFG-configuration-as-tested](CFG-configuration-as-tested/result.md). Environment: [00-environment-and-configuration](00-environment-and-configuration/result.md)._\n')
out.append('## What this changed in the guides\n')
out.append('| Finding | Proven by | Guide change |\n|---|---|---|')
for a,b,cc in [
 ('Lookup paths accept only `${ad.<adapter ID>.<attribute>}` and `${ds.<source ID>.<attribute>}`; `${hostUUID}` and `${fleetHostID}` are "Unknown Key"; a criterion value is compared as literal text','P-6','Ping Step 6'),
 ('`fleetHostID` does **not** need to be mapped to the policy contract (an earlier finding said it did; retracted)','P-6b','Step removed from Ping Step 6'),
 ('Import script missed Mozilla\'s apt Firefox and the snap Chromium store; reruns needed for new users and new Firefox profiles','P-3, P-4','Script fix + Ping Step 3 (Linux) note'),
 ('Browser auto-select must name the host and port that request the certificate (9032), not the sign-in URL port; Firefox needs its own policy','P-14','Ping "Skip the certificate picker"'),
 ('Linux certificates are not renewed by Fleet; rerunning the import script replaces the old one','P-15','Ping Step 3 (Linux) note'),
 ('A brand-new host signs in before its first policy run','P-13','Open question for the team (no guide change yet)'),
 ('Fleet noticed a policy change 146 to 160 s after Refetch in this run (35 to 70 s earlier in the day)','P-9, P-10','Guide wording "about a minute" is optimistic'),
 ('Export script could leave empty or truncated CSVs; Duo refuses an empty list','D-9, D-10','Export script fix (temp files, 50% shrink guard, `FORCE`)'),
 ('Duo\'s script holds its keys; keep only the keys as secrets and commit a keyless copy','D-4, D-6','Duo Step 5 (workflow + secrets)'),
 ('Duo Desktop only runs on x86-64 Linux; browser asks for local-network permission','D-1, D-5','Duo prerequisites and troubleshooting')]:
    out.append(f'| {a} | {b} | {cc} |')
out.append('\n## Lab workarounds and limits (read before quoting a result)\n')
for t in [
 '**Duo Desktop on Linux ran under emulation.** Duo supports x86-64 Linux only. The lab VM is ARM, so the x86-64 package runs through QEMU 10 user-mode emulation with `DOTNET_EnableWriteXorExecute=0`, a loader link, x86 libraries and a virtual TPM. This is a lab trick, not a supported setup. D-1 is PARTIAL because of it.',
 '**Duo Desktop log shows "Error loading computer key" and sends unsigned health data** even with the virtual TPM. Duo still marked the endpoint trusted. Whether the TPM matters was not tested in isolation.',
 '**The second factor was a bypass code**, because the test user\'s only enrolled factor is Touch ID on the Mac.',
 '**Sign-ins were made by curl from inside the VM** (a real client with the host\'s certificate, same requests a browser makes) and by Firefox and Chromium for the browser tests.',
 '**Chromium** needed `--ozone-platform=wayland` in this VM and trust for the lab CA in its certificate store. **Firefox** needed a crash-prompt setting because the harness kills it between cases.',
 '**One Fleet host, one Linux VM.** The "critical policy drops the host from Duo\'s list" chain needs a second healthy host; D-8 shows the Duo half by replacing the list.',
 '**The 5-minute sync (D-12) is a snapshot**; the day-long result is recorded tomorrow.',
 '**PingFederate findings are for version 13.1.3 with one adapter configuration.** Other versions or contexts may name things differently.']:
    out.append(f'- {t}')
out.append('\n## Not run on Linux\n')
for t in ['**L-2** (a VM without a product UUID, Duo Desktop 4.7.0 falls back to `/etc/machine-id`): not tested.',
 '**D-7** (new host appears after the next sync): shown on macOS (see `RESULTS.md`); on Linux the host kept its UUID after re-enrolling, so the list did not change.',
 '**Fleet-driven Duo Desktop install on Linux** (custom package + policy automation): installed by hand with `dpkg`.',
 '**Fleet\'s EST/Hydrant certificate flow for Linux:** step-ca does not do EST, so certificates were issued directly.',
 '**P-1, P-2, P-16, D-2, D-11:** macOS and Windows tests; see `RESULTS.md` for macOS. Windows is blocked on x64 hardware.']:
    out.append(f'- {t}')
out.append('\n## Related evidence\n')
out.append('- macOS results and the renewal test: [`RESULTS.md`](../../RESULTS.md) and [`renewal/`](../renewal/) (a watcher logs the macOS certificate every 5 minutes; a 7-hour certificate that crosses midnight UTC should renew on Fleet\'s hourly job).')
out.append('- Duo Admin Panel records: [`_duo-admin-records/`](_duo-admin-records/).')
out.append('- Tests are re-runnable: [`evidence/*.sh`](../) are the scripts that produced this folder.')
out.append(f'\n_Generated {datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")} from `results.tsv` and each test\'s `result.md`._')
open(f'{EV}/REPORT.md','w').write('\n'.join(out)+'\n')
print(len(rows),'results;',c)
