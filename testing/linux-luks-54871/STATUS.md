# Status: Linux LUKS session (#54871) — read by other lab sessions

Updated: 2026-10-15 20:38 CEST

## Shared resources I use
- UTM VMs **luks-ubuntu** (stopped, black display after first boot, see RESULTS S-8) and **luks-ubuntu2** (new, running the installer, created by UTM scripting only, NVMe disk + virtio-ramfb like the BitLocker VM). I won't touch
  bitlocker-lab (any copy), lab-linux, lab-windows or Linux.
- **I will NOT quit or restart UTM** (I know bitlocker-lab is running). New VMs are created with UTM scripting only (UTM stays up).
  If I ever need UTM restarted I will ask Adam first.
- Disk: ~62 GB free at 2026-10-15 20:29 CEST. I'm downloading a 4 GB Ubuntu ISO into `/Users/adam/Downloads/fleet-54871-lab/vm/iso` and a VM disk grows to ~10 GB.
- Fleet: fleet 5 "Linux LUKS Lab" only (escrow on). No Fleet API changes outside it.
- GitOps: **the shared "Apply latest configuration to Fleet" run has been failing** since fleets/ios-google-lab.yml was added: the repo secret
  `FLEET_IOS_GOOGLE_LAB_ENROLL_SECRET` is empty (Adam sets it with the lab's `tools/setup-ios-secret.sh`). Don't read a red apply as caused by your change.
- Mac settings I rely on: AirPlay Receiver is ON (port 7000, for the iPhone mirror). Please leave it.

## Now
luks-ubuntu2 is running the Ubuntu 24.04.5 installer (ISO attached at runtime; UTM scripting ignores the image on removable drives, as the BitLocker notes found). I click through
the pages and stop at the passphrase and account password pages for Adam to type. Next: first boot check, then S-3..S-9 and the key slot tests (Q1, Q2).
Pushes: I never push the GitOps repo. If a push is needed I will say so in the chat first; Adam pushes.

## Findings other sessions may care about
- UTM scripting ignores `source` for removable drives in some cases (bitlocker lab saw the same); don't rely on it.
- `utmctl` returns exit 0 even on errors: check the output text.
