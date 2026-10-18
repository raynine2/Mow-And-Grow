#!/usr/bin/env python3
"""Draw the particle / flash textures for the hit effects into assets/fx/*.png.

    python3 tools/fx/make_textures.py
    ROBLOX_API_KEY=... python3 tools/upload_models.py --fx      # upload them, writes src/shared/FxIds.luau

Every texture is white (or white with soft shading) on transparent, so the game tints it with the particle
Color. Shapes are drawn as signed-distance fields at 4x size and scaled down, so the edges are smooth.
Long shapes (splinter, blade) point UP: with Orientation = VelocityParallel the particle's up axis follows
its flight direction.
"""
import math, os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "fx")
SS = 4  # supersampling


def grid(n):
    """Coordinates in [-1, 1] (y up) for an n x n image drawn at SS x."""
    m = n * SS
    v = (np.arange(m) + 0.5) / m * 2 - 1
    x, y = np.meshgrid(v, -v)
    return x, y


def save(name, alpha, shade=None, n=256):
    """alpha: coverage 0..1 at SS size; shade: brightness 0..1 (default white)."""
    a = np.clip(alpha, 0, 1)
    rgb = np.ones(a.shape) if shade is None else np.clip(shade, 0, 1)
    img = np.dstack([rgb, rgb, rgb, a])
    im = Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((n, n), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def edge(d, px):
    """Signed distance (negative inside) -> coverage with an anti-aliased edge `px` wide (in [-1,1] units)."""
    return np.clip(0.5 - d / px, 0, 1)


def polygon_sdf(x, y, pts):
    """Signed distance to a closed polygon (negative inside)."""
    pts = np.asarray(pts, float)
    d = np.full(x.shape, 1e9)
    inside = np.zeros(x.shape, bool)
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]; bx, by = pts[(i + 1) % n]
        ex, ey = bx - ax, by - ay
        wx, wy = x - ax, y - ay
        t = np.clip((wx * ex + wy * ey) / max(ex * ex + ey * ey, 1e-12), 0, 1)
        dx, dy = wx - ex * t, wy - ey * t
        d = np.minimum(d, dx * dx + dy * dy)
        c1 = (ay <= y) & (by > y); c2 = (ay > y) & (by <= y)
        cross = ex * wy - ey * wx
        inside ^= (c1 & (cross > 0)) | (c2 & (cross < 0))
    return np.where(inside, -1, 1) * np.sqrt(d)


def glow():
    x, y = grid(256)
    r = np.hypot(x, y)
    a = np.exp(-(r / 0.42) ** 2) * 0.85 + np.exp(-(r / 0.13) ** 2) * 0.6
    save("glow", a * (r < 1))


def flare():
    """Bright core with 4 long thin rays and 4 short diagonal ones (the hit flash)."""
    x, y = grid(256)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    core = np.exp(-(r / 0.16) ** 2)
    rays4 = np.exp(-(np.abs(np.sin(2 * th)) * r / 0.035) ** 2) * np.clip(1 - r, 0, 1) ** 1.5
    rays8 = np.exp(-(np.abs(np.sin(2 * th + math.pi / 2)) * r / 0.03) ** 2) * np.clip(1 - r / 0.55, 0, 1) ** 2
    save("flare", np.clip(core + rays4 + rays8 * 0.7, 0, 1))


def burst():
    """Comic impact star: 10 jagged spikes around a solid middle (the punch POW)."""
    x, y = grid(256)
    pts = []
    rng = np.random.default_rng(4)
    k = 10
    for i in range(k * 2):
        a = i / (k * 2) * 2 * math.pi + 0.15
        rad = (0.92 + rng.uniform(-0.08, 0.06)) if i % 2 == 0 else (0.45 + rng.uniform(-0.05, 0.05))
        pts.append((math.cos(a) * rad, math.sin(a) * rad))
    d = polygon_sdf(x, y, pts)
    a = edge(d, 0.012)
    # soft hole in the middle so it reads as a shock star, not a blob
    r = np.hypot(x, y)
    a = a * (0.55 + 0.45 * np.clip((r - 0.12) / 0.3, 0, 1))
    save("burst", a)


def splinter():
    """Long jagged shard pointing up, like the trailer's flying splinters: a zigzag on both sides, the teeth
    of one side between the teeth of the other, fattest a bit below the middle."""
    x, y = grid(256)
    n = 12
    right, left = [], []
    for i in range(n + 1):
        t = i / n
        yy = -0.96 + 1.92 * t
        env = math.sin(math.pi * t) ** 0.7 * 0.3
        right.append((env * (1.0 if i % 2 == 0 else 0.5), yy))
        left.append((-env * (0.5 if i % 2 == 0 else 1.0), yy))
    pts = right + left[::-1]
    d = polygon_sdf(x, y, pts)
    shade = 0.8 + 0.2 * np.clip((y + 1) / 2, 0, 1) - 0.12 * np.clip(x * 3, 0, 1)
    save("splinter", edge(d, 0.012), shade)


def blade():
    """A chunky cut grass blade pointing up: wide flat base, pointed tip, a light mid-rib."""
    x, y = grid(256)
    pts = [(-0.26, -0.95), (0.26, -0.95), (0.2, 0.35), (0.0, 0.98), (-0.2, 0.35)]
    d = polygon_sdf(x, y, pts)
    rib = np.exp(-(x / 0.05) ** 2) * 0.12
    shade = 0.78 + 0.2 * np.clip((y + 1) / 2, 0, 1) + rib - 0.1 * np.clip(-x * 3, 0, 1)
    save("blade", edge(d, 0.012), shade)


def smoke():
    """Soft puffy cloud made of overlapping round blobs, a little shading toward the bottom."""
    x, y = grid(256)
    rng = np.random.default_rng(7)
    a = np.zeros(x.shape)
    for _ in range(9):
        cx, cy = rng.uniform(-0.35, 0.35), rng.uniform(-0.3, 0.3)
        rr = rng.uniform(0.28, 0.45)
        a = np.maximum(a, np.exp(-((np.hypot(x - cx, y - cy)) / rr) ** 4))
    a *= np.clip(1.2 - np.hypot(x, y), 0, 1)
    shade = 0.85 + 0.15 * np.clip((y + 1) / 2, 0, 1)
    save("smoke", a * 0.9, shade)


def ring():
    x, y = grid(256)
    r = np.hypot(x, y)
    a = np.exp(-((r - 0.78) / 0.07) ** 2) + 0.25 * np.exp(-((r - 0.7) / 0.18) ** 2)
    save("ring", np.clip(a, 0, 1))


def slash():
    """A crescent swipe: thick in the middle, tapering to sharp ends, bright inner edge, soft trailing glow."""
    x, y = grid(512)
    r = np.hypot(x, y + 0.35)
    th = np.arctan2(y + 0.35, x)
    t = np.clip((th - math.radians(25)) / math.radians(130), 0, 1)  # 0..1 along the arc
    along = np.where((th > math.radians(25)) & (th < math.radians(155)), np.sin(math.pi * t) ** 0.8, 0)
    width = 0.16 * along
    centre = 0.85
    d = np.abs(r - centre) - width
    core = edge(d, 0.01) * (along > 0.03)
    trail = np.exp(-((r - centre + 0.12) / 0.16) ** 2) * along * 0.35
    shade = 0.75 + 0.25 * np.clip((r - (centre - width)) / (2 * width + 1e-6), 0, 1)
    save("slash", np.clip(core + trail, 0, 1), shade, n=512)


def spark():
    x, y = grid(128)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    star = np.exp(-(np.abs(np.sin(2 * th)) * r / 0.06) ** 2) * np.clip(1 - r, 0, 1) ** 2
    save("spark", np.clip(star + np.exp(-(r / 0.12) ** 2), 0, 1), n=128)


if __name__ == "__main__":
    for f in (glow, flare, burst, splinter, blade, smoke, ring, slash, spark):
        f()
