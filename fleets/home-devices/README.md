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

A local scheduled task on the lab Mac (`~/.claude/scheduled-tasks/home-wifi-quic-check/`) runs hourly and only reads. It checks:

- Host 36 is in this fleet with the profile verified and `QuicAllowed` 0.
- Whether Chrome on host 36 has relaunched since 17:23, which makes the policy active.
- The lab Mac's Chrome QUIC failure count, against a baseline of 373 hosts and 4772 failures.

It appends one line per run to `~/Library/Logs/home-wifi-quic-check.log`. A flat failure count means the network has settled.

## Open items

- Relaunch Chrome on host 36 so the policy applies.
- QUIC off fixes Chrome only. The Claude desktop app runs on Chromium and has no policy for this. If it still stalls, the Wi-Fi isn't fixed. Next suspects: Deco HomeShield Security, and the ISP's handling of UDP 443.
- The NordVPN Chrome extension is unused and can be removed.
