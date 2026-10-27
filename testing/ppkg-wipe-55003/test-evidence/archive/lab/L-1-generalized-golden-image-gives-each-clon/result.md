# L-1: Generalized golden image gives each clone its own identity

- **Started:** 2026-10-26T21:48:22Z
- **Objective:** Sysprep /generalize the golden image so clones get unique machine IDs and Windows MDM hardware IDs
- **Expected:** Two clones enroll and both show MDM On and connected in Fleet at the same time

## Steps and evidence
- `01-clone.txt`: `vm/clone.sh new ppkg-golden-oobe ppkg-golden-gen2`
- `02-sysprep.txt`: `tools/vm-exec.sh ppkg-golden-gen2 '"MachineGuid before: " + (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Cryptog`
- `03-sysprep-done.txt`: `date -u +%T; /Applications/UTM.app/Contents/MacOS/utmctl status ppkg-golden-gen2`
- `004-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 236% CPU)
- `005-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 227% CPU)
- `006-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 99% CPU)
- `007-l1-a-now.png` (window screenshot: UTM / l1-a)
- `008-l1-b-now.png` (window screenshot: UTM / l1-b)
- `009-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 229% CPU)
- `010-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 223% CPU)
- `011-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 227% CPU)
- `012-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 211% CPU)
- `013-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 230% CPU)
- `014-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 227% CPU)
- `015-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 231% CPU)
- `016-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 99% CPU)
- `017-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 99% CPU)
- `018-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 234% CPU)
- `019-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 229% CPU)
- `020-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 232% CPU)
- `021-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 228% CPU)
- `022-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 230% CPU)
- `023-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 99% CPU)
- `024-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 237% CPU)
- `025-l1-a-25min.png` (window screenshot: UTM / l1-a)
- `026-l1-b-25min.png` (window screenshot: UTM / l1-b)
- `027-hang-before-cycle.png` (window screenshot: frame unchanged 90 s, QEMU 222% CPU)

22:10 to 22:36 UTC: both clones of the sysprep-generalized image (full guest tools) hung at Start boot option on every boot, warm and cold. The watchdog cycled them 12 times (watchdog.txt). Generalized images do not boot in this VM. L-1 waits on L-2.

## Result: BLOCKED

Generalized clones never boot (cold boots hang too). Depends on L-2 arms A and B.

_Finished 2026-10-26T22:36:52Z_
