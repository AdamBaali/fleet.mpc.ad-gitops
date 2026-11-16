# Home devices

Family Macs managed from the lab Fleet, apart from the lab fleets.

## What it sets

| Item | Why |
| --- | --- |
| `chrome-quic-off.mobileconfig` | The home Wi-Fi (Deco X10 mesh) drops HTTP/3 (QUIC) intermittently. Chrome stalls on some pages while Safari loads them. A phone hotspot works. Chrome's saved network state on two Macs here marks QUIC broken for hundreds of hosts. |
| `network-unified-logs.sh` | Pulls Wi-Fi link changes and network, DNS, and QUIC errors from the unified log. Prints a summary and saves the full log to `/Library/Logs/fleet-net-diag/`. Read-only. Set `HOURS` to widen the window. |

## Open item

QUIC off fixes Chrome only. The Claude desktop app runs on Chromium too and has no policy for this. The lasting fix is on the router.
