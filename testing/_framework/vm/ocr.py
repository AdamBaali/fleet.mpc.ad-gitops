#!/usr/bin/env python3
"""Local OCR for VM screenshots, so Claude reads a line of text instead of a picture.

Usage: ocr.py text  <png>            words on screen, one line per text line
       ocr.py find  <png> <phrase>   x y of the phrase's centre in screenshot pixels (exit 1 if absent)
       ocr.py match <png> <regex>    first line matching regex (exit 1 if none)
       ocr.py small <png> <out> [w]  copy scaled to width w (default 1024) for a model to read

Needs tesseract (brew install tesseract) and Pillow (python3 -m pip install --user pillow).
Runs tesseract twice, on the screen and on its inverse, at 2x: Windows draws dark text on light buttons inside dark
pages, and a single pass misses one or the other. --psm 12 (sparse text) finds lone button labels that --psm 11 missed.
"""
import csv, io, re, subprocess, sys, tempfile
from PIL import Image, ImageOps

def lines(png):
    """Text lines as lists of words with screen-pixel boxes. Uses tesseract's own line grouping for each pass, and
    keeps a line from the inverted pass only when its words aren't already found."""
    img = Image.open(png).convert("L")
    big = img.resize((img.width * 2, img.height * 2))
    found, out = [], []
    for n, variant in enumerate((big, ImageOps.invert(big))):
        with tempfile.NamedTemporaryFile(suffix=".png") as t:
            variant.save(t.name)
            tsv = subprocess.run(["tesseract", t.name, "-", "--psm", "12", "tsv"],
                                 capture_output=True, text=True).stdout
        groups = {}
        for r in csv.DictReader(io.StringIO(tsv), delimiter="\t", quoting=csv.QUOTE_NONE):
            if r.get("level") != "5" or not r["text"].strip() or float(r["conf"]) < 40:
                continue
            w = dict(t=r["text"], x=int(r["left"]) // 2, y=int(r["top"]) // 2,
                     w=int(r["width"]) // 2, h=int(r["height"]) // 2)
            groups.setdefault((r["block_num"], r["par_num"], r["line_num"]), []).append(w)
        for ws in groups.values():
            new = [w for w in ws if not any(abs(o["x"] - w["x"]) < 6 and abs(o["y"] - w["y"]) < 6 for o in found)]
            if n == 0 or len(new) == len(ws):
                out.append(sorted(ws, key=lambda w: w["x"])); found += ws
    return sorted(out, key=lambda l: (min(w["y"] for w in l), l[0]["x"]))

def main():
    mode, png = sys.argv[1], sys.argv[2]
    if mode == "small":
        img = Image.open(png); width = int(sys.argv[4]) if len(sys.argv) > 4 else 1024
        img.resize((width, img.height * width // img.width)).save(sys.argv[3]); print(sys.argv[3]); return 0
    ls = lines(png)
    if mode == "text":
        for l in ls: print(" ".join(w["t"] for w in l))
        return 0
    if mode == "match":
        rx = re.compile(sys.argv[3], re.I)
        for l in ls:
            s = " ".join(w["t"] for w in l)
            if rx.search(s): print(s); return 0
        return 1
    if mode == "find":
        want = sys.argv[3].lower().split()
        for l in ls:
            got = [w["t"].lower() for w in l]
            for i in range(len(got) - len(want) + 1):
                if all(want[j] in got[i + j] for j in range(len(want))):
                    hit = l[i:i + len(want)]
                    x0 = min(w["x"] for w in hit); x1 = max(w["x"] + w["w"] for w in hit)
                    y0 = min(w["y"] for w in hit); y1 = max(w["y"] + w["h"] for w in hit)
                    print((x0 + x1) // 2, (y0 + y1) // 2); return 0
        return 1
    print(__doc__); return 2

sys.exit(main())
