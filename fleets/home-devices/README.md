# Home devices

Family Macs managed from the lab Fleet, apart from the lab fleets.

## What it sets

| Item | Why |
| --- | --- |
| `chrome-quic-off.mobileconfig` | The home Wi-Fi (Deco X10 mesh) drops HTTP/3 (QUIC) intermittently. Chrome stalls on some pages while Safari loads them. A phone hotspot works. Chrome's saved network state on two Macs here marks QUIC broken for hundreds of hosts. |
| `network-unified-logs.sh` | Pulls Wi-Fi link changes and network, DNS, and QUIC errors from the unified log. Prints a summary and saves the full log to `/Library/Logs/fleet-net-diag/`. Read-only. Set `HOURS` to widen the window. |

## Hosts

The home Mac is host 36. It was moved here by hand (`fleetctl hosts transfer`), since GitOps doesn't assign hosts.
The nightly apply keeps this fleet, so the host stays put.

## Findings (2026-11-16)

| Check | Result |
| --- | --- |
| Chrome network state, home Mac | QUIC marked broken for 186 hosts, up to 83 times for one host |
| Chrome network state, lab Mac on the same Wi-Fi | Same pattern: 373 hosts, 4772 failures. So the cause is the network, not the Mac |
| Claude desktop app (Chromium) | QUIC marked broken too, which explains why it fails while Safari works |
| DNS, pf rules, path MTU, Wi-Fi signal | Normal on both Macs |
| NordVPN | App off, its pf anchor empty. The Chrome extension is installed but sets no proxy |
| Deco X10 | Public WAN IP, so no double NAT. Firmware 1.4.0 Build 20251222 is current. IPv6 was half set up: a ULA prefix and a default route with no internet IPv6 |
| Live HTTP/3 test | Fresh and idle connections worked during testing. The failure is intermittent and wasn't reproduced on demand |

Two dead ends to skip next time:

- The osquery `curl` table returns no response code for sites with large response headers (YouTube, X, ChatGPT, Gmail). It looks like a block but isn't. Confirm with real curl.
- Cloudflare's WAF in front of fleet.mpc.ad blocks ad hoc `run-script` bodies full of network probes. Ship scripts through `controls.scripts` instead.

## Changes made

| When (UTC) | Change |
| --- | --- |
| 17:12 | Chrome profile with `QuicAllowed` false, first for hosts in no fleet, then moved to this fleet |
| 17:23 | Profile verified on host 36. `QuicAllowed` likely needs a Chrome relaunch, and Chrome on host 36 had been running since 16:42, so the policy isn't confirmed active yet |
| 17:26 | Deco: QoS off, IPv6 off. IPv6 default routes left both Macs as expected |

Pages loaded normally before the Deco changes, so those changes weren't the fix.

## Monitoring

### Saved reports

`lib/macos/reports/home-wifi.reports.yml` runs in this fleet and in Ping Duo Lab. The lab Mac shares the home Wi-Fi and serves as the control.
No live queries are needed. Read the results in Fleet under **Reports**, or with `fleetctl api /api/v1/fleet/queries/<id>/report`.

| Report | Every | Answers |
| --- | --- | --- |
| Home Wi-Fi - Chrome HTTP/3 policy | 1 h | Is `QuicAllowed` 0 on the Mac? |
| Home Wi-Fi - Browser and Claude app processes | 15 min | Has Chrome relaunched since the profile arrived, which makes the policy active? |
| Home Wi-Fi - Wi-Fi link | 15 min | Signal, noise, channel and rate at the time of a stall |
| Home Wi-Fi - Web reachability | 15 min | HTTPS response and round trip to small endpoints |
| Home Wi-Fi - IPv6 and default routes | 1 h | Did IPv6 come back half set up? |
| Home Wi-Fi - DNS resolvers | 1 h | Which resolvers are in use |
| Home Wi-Fi - VPN and proxy software | 1 h | VPN apps and Chrome extensions that can set a proxy |

The reports keep the latest result per host. History comes from the hourly check below.

### Hourly check

A local scheduled task on the lab Mac (`~/.claude/scheduled-tasks/home-wifi-quic-check/`) runs hourly and only reads. It reads the saved report results above, plus the lab Mac's own Chrome QUIC failure count, against a baseline of 373 hosts and 4772 failures.
It appends one line per run to `~/Library/Logs/home-wifi-quic-check.log`. A flat failure count means the network has settled.

## Is it the Deco or the ISP?

Chrome on the lab Mac keeps counting QUIC failures. Run each test for a day and compare the count:

1. **Lab Mac wired to a Deco LAN port.** If the failures stop, the Wi-Fi or mesh is the cause. Look at the Deco: HomeShield Security, Fast Roaming, the wireless backhaul between units.
2. **Lab Mac wired straight to the ISP's fibre box (ONT)**, with the Deco unplugged. If the failures continue here, the ISP is the cause.
3. If the failures stop in test 2 but not in test 1, the Deco's routing (NAT) is the cause.

### ISP report, if test 2 still fails

> Our connection breaks HTTP/3 (QUIC, UDP port 443) intermittently. Browsers that use it stall on page loads, while the same pages load over TCP.
> We tested with a computer connected straight to the ONT, with no router of our own, so the fault is upstream of our equipment.
> Public IP 109.111.108.140 (DHCP, one-hour lease). Over <N> days, Chrome recorded HTTP/3 failures to <N> sites, including Google, Cloudflare and Microsoft.
> Do you rate-limit, filter, or shorten NAT timeouts for UDP 443 traffic, or run carrier-grade NAT on this line? A traceroute shows 10.10.5.214 at hop 3.

Fill in the counts from the hourly check log before sending.

## Open items

- Relaunch Chrome on host 36 so the policy applies.
- QUIC off fixes Chrome only. The Claude desktop app runs on Chromium and has no policy for this. If it still stalls, the Wi-Fi isn't fixed. Run the Deco or ISP tests above.
- The NordVPN Chrome extension is unused and can be removed.
