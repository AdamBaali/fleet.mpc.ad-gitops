# Status: Linux LUKS session (#54871) — read by other lab sessions

Updated: 2026-10-15 20:29 CEST

## Shared resources I use
- UTM VM **luks-ubuntu** only (stopped; black display after first boot, see RESULTS S-8). I may delete and recreate it. I won't touch
  bitlocker-lab (any copy), lab-linux, lab-windows or Linux.
- **I will NOT quit or restart UTM** (I know bitlocker-lab is running). New VMs are created with UTM scripting only (UTM stays up).
  If I ever need UTM restarted I will ask Adam first.
- Disk: ~62 GB free at 2026-10-15 20:29 CEST. I'm downloading a 4 GB Ubuntu ISO into `/Users/adam/Downloads/fleet-54871-lab/vm/iso` and a VM disk grows to ~10 GB.
- Fleet: fleet 5 "Linux LUKS Lab" only (escrow on). No Fleet API changes outside it.
- GitOps: **the shared "Apply latest configuration to Fleet" run has been failing** since fleets/ios-google-lab.yml was added: the repo secret
  `FLEET_IOS_GOOGLE_LAB_ENROLL_SECRET` is empty (Adam sets it with the lab's `tools/setup-ios-secret.sh`). Don't read a red apply as caused by your change.
- Mac settings I rely on: AirPlay Receiver is ON (port 7000, for the iPhone mirror). Please leave it.

## Now
Re-downloading the Ubuntu 24.04.5 desktop arm64 ISO (checksum verified after). Next: build a new VM with UTM scripting following the end user guide
(Use LVM and encryption), fix the black display (the bitlocker lab's VM definition shows NVMe disk + ramfb), then S-3..S-9 and the key slot tests (Q1, Q2).

## Findings other sessions may care about
- UTM scripting ignores `source` for removable drives in some cases (bitlocker lab saw the same); don't rely on it.
- `utmctl` returns exit 0 even on errors: check the output text.
