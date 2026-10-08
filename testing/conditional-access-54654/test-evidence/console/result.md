# Console pages (2026-10-08)
Window-only captures of Adam's browser (Fleet and Duo Admin, lab accounts). The browser profile area, admin name, MAC address, public IP and serial number are masked.

| File | What it shows |
| --- | --- |
| `fleet-mac-host-policies.png` | Mac host (`MPC-Adam`, fleet Ping Duo Lab): critical policy "CA test - flag file absent" passes, "always fails (non-critical)" fails, Duo Desktop and Firefox installed policies pass |
| `fleet-linux-host-policies.png` | Linux host (`lab-linux`): same two CA test policies (critical passes, non-critical fails) |
| `fleet-os-settings-ping-duo-lab.png` | Controls > OS settings for the Ping Duo Lab fleet: Lab CA client certificate, Lab CA root certificate and other profiles; Verified 1 host, Failed 0 |
| `fleet-ca-list.png` | Settings > Integrations > Certificate authorities: `LAB_CA`, Custom SCEP (the entry itself is not opened, so the challenge is not shown) |
| `duo-endpoints-trusted.png` | Duo Endpoints: both lab hosts (Mac OS X with Chrome, Linux with Firefox) are **Trusted Endpoint: Yes**, "Generic with Duo Desktop" |
| `duo-applications-web-sdk.png` | Duo Applications: the Web SDK app with the group policy "Fleet lab - trusted endpoints only" for group `fleet-lab` |

Not captured: the Duo authentication log (the URL tab showed "Not Found") and the PingFederate admin console (the browser pane refuses https://localhost; capture it in your own browser at https://localhost:9999/pingfederate if wanted).

## Added later (2026-10-08)
| File | What it shows |
| --- | --- |
| `fleet-ca-lab-ca-settings.png` | The LAB_CA edit form: name `LAB_CA`, SCEP URL `https://scep.mpc.ad/scep/fleet-scep`; the challenge field is masked by Fleet (dots only) |
| `duo-authentication-log.png` | Duo Authentication Log (zoomed out, last 24 hours, all rows for `lab-test`, Web SDK app). **Mac:** Denied "Endpoint is not trusted" at 9:02:55 UTC (the D-8 block) then Granted at 9:05:43 after the sync restored the Mac, both "as reported by Duo Desktop". Earlier Mac rows: Denied "Endpoint is not trusted" 11:22 on Oct 7 (before the Mac was in the list), Granted 12:43. **Linux (Ubuntu 24.04, Duo Desktop under emulation):** Denied "Duo Desktop was not installed or running" 5:38 PM, Denied "Endpoint is not trusted" 5:46 PM and 6:50 PM (D-8), Granted with a bypass code at 5:56, 6:46 and 6:53 PM. Your admin name and the profile area are masked |
