#!/usr/bin/env bash
# Masked luksDump from the guest: keeps version, UUID, cipher, keyslot list, tokens, segments; masks salts, key material sizes stay.
# The master key DIGEST is shown shortened (first 16 hex chars) so before/after can be compared without printing the whole value.
# usage: tools/luksdump.sh <vm> [device]
VM="$1"; DEV="${2:-/dev/nvme0n1p3}"
"$(dirname "$0")/vm-run.sh" "$VM" "cryptsetup luksDump $DEV" | python3 -I -c '
import sys,re
for l in sys.stdin:
    l=l.rstrip("\n")
    m=re.match(r"^(\s*)(Salt:|Digest:)\s*(.*)$",l)
    if m:
        v=m.group(3).replace(" ","")
        if m.group(2)=="Digest:": l=f"{m.group(1)}Digest:      {v[:16]}... (shortened, {len(v)//2} bytes)"
        else: l=f"{m.group(1)}Salt:        <masked>"
    elif re.match(r"^\s+([0-9a-f]{2}\s+){7}",l): l=re.sub(r"[0-9a-f]{2}","..",l)
    print(l)'
