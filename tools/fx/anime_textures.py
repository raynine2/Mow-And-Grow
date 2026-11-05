#!/usr/bin/env python3
"""The films' anime FX textures (Films v2 round 2, owner 5 Nov: "i dont feel like ur using good fx on some parts like
the slash ... look at the video look how they did it"): flat, crisp, opaque shapes like the reference's (Sukuna Raid
intro 18.25: hard white slash wedges across the frame; 15.3: long tapered streaks; 16.95: a horizontal flare).
White on transparent (the game tints them), drawn at 4x and scaled down so the edges are clean but hard.

    python3 tools/fx/anime_textures.py        writes assets/fx/anime/*.png

  stroke.png   a long lens (pointed at both ends), for a Beam bent into a slash arc (U = along the cut)
  glow.png     the same lens, wider and soft: the coloured glow under a stroke
  wedge.png    the screen slash: a long hard white wedge, its thick end left, two thin slivers along it
  streak.png   a horizontal flare: a hard thin line, bright in the middle, a soft halo
"""
import math, os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "fx", "anime")
SS = 4


def save(name, a, w, h):
    a = np.clip(a, 0, 1)
    img = Image.fromarray((a * 255).astype(np.uint8), "L").resize((w, h), Image.LANCZOS)
    rgba = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    rgba.putalpha(img)
    os.makedirs(OUT, exist_ok=True)
    rgba.save(os.path.join(OUT, name))
    print(name, w, h)


def lens(w, h, fill=0.92, power=0.55, soft=0.0):
    """u along x (0..1), v across y (-1..1): inside where |v| < fill * sin(pi u)^power."""
    W, H = w * SS, h * SS
    u = (np.arange(W) + 0.5) / W
    v = ((np.arange(H) + 0.5) / H) * 2 - 1
    U, Vv = np.meshgrid(u, v)
    # (thickest a little ahead of the middle, both ends sharp points)
    half = fill * np.sin(np.pi * U ** 0.8) ** power
    d = half - np.abs(Vv)  # >0 inside
    if soft > 0:
        return np.clip(d / soft + 0.5, 0, 1) * np.clip(half / max(fill, 1e-6) * 3, 0, 1)
    return np.clip(d * H / 2 + 0.5, 0, 1)  # one pixel (at SS) of antialias


def wedge(w, h):
    W, H = w * SS, h * SS
    img = Image.new("L", (W, H), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    # the main wedge: thick at the left, a point at the right, its top edge straight, its bottom edge curving up
    pts = [(0, H * 0.18)]
    for i in range(0, 41):
        k = i / 40
        x = k * W * 0.98
        top = H * (0.18 + 0.30 * k)
        pts.append((x, top))
    for i in range(40, -1, -1):
        k = i / 40
        x = k * W * 0.98
        bot = H * (0.86 - 0.36 * (k ** 0.8))
        pts.append((x, bot))
    d.polygon(pts, fill=255)
    # two thin slivers along it, offset, ragged ends
    for (y0, y1, x0, x1) in [(0.06, 0.10, 0.10, 0.80), (0.92, 0.95, 0.04, 0.62)]:
        d.polygon([(W * x0, H * y0), (W * x1, H * (y0 + y1) / 2 + H * 0.12 * (x1 - x0)), (W * x0, H * y1)], fill=255)
    a = np.asarray(img).astype(np.float32) / 255.0
    return a


def streak(w, h):
    W, H = w * SS, h * SS
    u = ((np.arange(W) + 0.5) / W) * 2 - 1
    v = ((np.arange(H) + 0.5) / H) * 2 - 1
    U, Vv = np.meshgrid(u, v)
    along = (1 - np.abs(U)) ** 1.6
    core = np.clip((0.09 * along - np.abs(Vv)) * H / 2 + 0.5, 0, 1)  # a hard thin line
    halo = np.exp(-(Vv / (0.35 * along + 0.02)) ** 2) * along * 0.55
    mid = np.exp(-(U ** 2 + (Vv * 4) ** 2) / 0.02) * 0.9
    return np.clip(core + halo + mid, 0, 1)


if __name__ == "__main__":
    save("stroke.png", lens(512, 64, 0.94, 1.15), 512, 64)
    soft = lens(512, 128, 0.8, 1.0, soft=0.35)
    soft = np.asarray(Image.fromarray((soft * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * SS))).astype(np.float32) / 255.0
    save("glow.png", soft * 1.2, 512, 128)
    save("wedge.png", wedge(1024, 192), 1024, 192)
    save("streak.png", streak(512, 64), 512, 64)
