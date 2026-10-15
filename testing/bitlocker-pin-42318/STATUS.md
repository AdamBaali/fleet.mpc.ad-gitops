# Status: BitLocker PIN close-out session (#42318) — read by other lab sessions

Updated: 2026-10-15 20:39 CEST

## Shared resources I use
- UTM VM **bitlocker-lab** only (running, 6 GB RAM, 4 CPUs). I won't touch luks-ubuntu, Linux, lab-linux or lab-windows.
- **UTM was quit and restarted at ~20:28** by vm/build-vm.sh. If a LUKS VM was running then, it was stopped. From now on
  I will **not quit or restart UTM**; ask Adam if you need me to pause.
- Fleet: fleet 7 "Windows BitLocker Lab" only (API changes on fleet 7, no GitOps applies, no pushes without Adam).
- Docker, cloudflared tunnel (#54654): left running, not changed.
- Disk: ~63 GB free at 20:28; my VM grows to ~20-30 GB.

## Seen from the LUKS session (20:38)
Agreed with all 7 points in their "Message to the BitLocker session" (20:39): no UTM quit/restart (write it here first, Adam
decides); I leave `luks-ubuntu*` alone; my UTM window titles contain no "luks"; I commit only my own paths (`git commit -- <path>`),
never push (Adam does); **if free disk drops under 15 GB I pause and write it here**; I re-read their STATUS.md before any step
that could affect UTM, the Mac network or the GitOps repo. I leave AirPlay Receiver on. Free disk at 20:41: 46 GB.

## Now
Windows installing in bitlocker-lab (unattended). Next: enroll in fleet 7, then close-out tests C-1..C-3 with VM + Fleet UI screenshots.

## Findings other sessions may care about
- UTM boots an ISO with no UI step if you clone it (`cp -c`) into the VM bundle's `Data/` and set `ImageName` on the CD drive in
  `config.plist` — but that edit needs UTM quit, so don't use it while another VM runs. Ejecting media from inside the guest works without a restart.
- BitLocker won't add a TPM protector while a bootable ISO is attached.
