# Open items
- Repo secret `FLEET_LINUX_LUKS_LAB_ENROLL_SECRET` is not set yet. Without it the GitOps apply fails on the new fleet.
- GitOps repo has uncommitted files from the #54654 lab (`ping-duo-lab.yml`, duo lib files). Left alone.
- Does Fleet Premium licence apply on fleet.mpc.ad? Escrow is a Premium feature. Check in the UI.
- Arch arm64 image: not checked yet.

## 2026-10-15 UTM input notes (for any session driving UTM)
- `input keystroke` text with `\n` types "yes" but does NOT press Return in a server-installer console. Use set-1 scan codes for Return: `input scan code ... codes {28, 156}`. (AT set 2 codes `90, 240, 90` did nothing.)
- The Ubuntu desktop live ISO is black on `virtio-ramfb`; `virtio-gpu-pci` works. The desktop autoinstall crashed after ~28 min with no useful log; the server ISO + cloud-init (DMI serial `ds=nocloud-net;s=http://192.168.64.1:18080/`) works.
- Autoinstall review pages print the config including secrets: never screenshot them.
