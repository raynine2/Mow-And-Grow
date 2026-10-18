#!/usr/bin/env python3
"""Join the frames fx_sim.py rendered into one labelled contact sheet:  python3 tools/preview/fx_sheet.py out.png"""
import json, math, os, sys
from PIL import Image, ImageDraw

out = sys.argv[1]
info = json.load(open(out + ".json"))
frames = info["frames"]
w, h = Image.open(frames[0][1]).size
cols = 3; rows = math.ceil(len(frames) / cols)
sheet = Image.new("RGB", (w * cols, h * rows), (20, 20, 20))
for i, (tau, path) in enumerate(frames):
    im = Image.open(path).convert("RGB")
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 170, 22), fill=(0, 0, 0))
    d.text((6, 5), "%s  t=%+.3fs" % (info["event"], tau), fill=(255, 255, 255))
    sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    os.remove(path)
sheet.save(out)
os.remove(out + ".json")
print("sheet ->", out)
