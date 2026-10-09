#!/usr/bin/env python3
# Builds the screenshots proposed for the guide (proposed/images/) from test-evidence/.
# The edits stay in code so a reviewer can see exactly what changed from the raw evidence.
# usage: python3 -I scripts/guide-images.py test-evidence proposed/images <Roboto-Regular .ttf/.woff/.woff2>
# Roboto matches the Admin console, so the redrawn "Asset tags" label and placeholder serial blend in.
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

EV = Path(sys.argv[1])          # test-evidence/
OUT = Path(sys.argv[2])         # output folder
FONT = sys.argv[3]              # Roboto Regular
OUT.mkdir(parents=True, exist_ok=True)

def save(im, name, icc=None):
    if im.mode == "RGBA" and np.array(im)[..., 3].min() == 255:
        im = im.convert("RGB")
    kw = {"optimize": True}
    if icc:
        kw["icc_profile"] = icc
    im.save(OUT / name, **kw)   # no exif / xmp
    print(name, im.size)

def draw_text_at(d, xy_ink_topleft, text, size, fill):
    f = ImageFont.truetype(FONT, size)
    l, t, r, b = f.getbbox(text)
    x, y = xy_ink_topleft
    d.text((x - l, y - t), text, font=f, fill=fill)

# 1. Managed: redraw the "Asset tags" label and replace the black mask with a placeholder serial.
src = Image.open(EV / "iphone/E-2b-idp-path-run-through/02-console-managed-serial-asset-tag-masked.png").convert("RGB")
d = ImageDraw.Draw(src)
d.rectangle([1260, 888, 1560, 992], fill=(255, 255, 255))
draw_text_at(d, (1283, 898), "Asset tags", 27.4, (117, 117, 117))
draw_text_at(d, (1284, 947), "XXXXXXXXXX", 27.4, (0, 0, 0))
save(src.crop((0, 0, src.width, 1290)), "01-google-device-managed-by-fleet.png")

# 2. Unmanaged: crop the empty space under the card.
src = Image.open(EV / "iphone/E-2-fleet-stops-counting-the-iphone/02-console-fleet-custom-unmanaged.png").convert("RGB")
# The search bar held a half-typed search ("Chang"); clear it.
ImageDraw.Draw(src).rectangle([388, 26, 460, 56], fill=(246, 246, 246))
save(src.crop((0, 0, src.width, 685)), "02-google-device-unmanaged.png")

# 3. Access level condition: the "Context conditions" card only, with a short editor.
src = Image.open(EV / "iphone/C-1e-keyless-exists-condition/01-condition-saved.png").convert("RGB")
top, left, right = 884, 16, 2120
yb = 1730                                   # new editor bottom border
card_pad = 56
crop = src.crop((left, top, right, yb + 2 + card_pad + 30)).copy()
a = np.array(crop)
off = lambda x, y: (x - left, y - top)
# Editor bottom border (2px, same grey as its sides), gutter border kept.
ex0, ex1 = off(111, 0)[0], off(2024, 0)[0]
by = yb - top
a[by:by + 2, ex0:ex1 + 1] = 224
# White card body below the editor.
cx0, cx1 = off(47, 0)[0], off(2088, 0)[0]
a[by + 2:by + 2 + card_pad, cx0:cx1 + 1] = 255
# Card bottom edge: same soft shadow as the card's left edge, then page background.
shadow = [208, 221, 228, 232, 235, 237, 237]
y0 = by + 2 + card_pad
a[y0:, :] = 238
for i, v in enumerate(shadow):
    a[y0 + i, cx0 - 7 + i:cx1 + 8 - i] = v
# Side shadows continue to the new bottom edge.
crop = Image.fromarray(a.astype(np.uint8))
save(crop, "03-access-level-condition.png")

# 4. iPhone, blocked.
src = Image.open(EV / "iphone/E-2b-idp-path-run-through/04-r3-blocked-live.png")
icc = src.info.get("icc_profile")
save(src.convert("RGBA"), "04-iphone-blocked.png", icc)

# 5. iPhone, sign in again: take the header from the blocked screen to drop the tooltip and button highlight.
blocked = Image.open(EV / "iphone/E-2b-idp-path-run-through/04-r3-blocked-live.png").convert("RGBA")
src = Image.open(EV / "iphone/E-2b-idp-path-run-through/05-r4-please-sign-in-again.png")
icc = src.info.get("icc_profile")
src = src.convert("RGBA")
box = (470, 168, 662, 300)
src.paste(blocked.crop(box), box[:2])
save(src, "05-iphone-sign-in-again.png", icc)
