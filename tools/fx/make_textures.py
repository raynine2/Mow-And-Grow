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


# ---------------------------------------------------------------------------------------------------------------
# flipbooks: 16 frames in a 4x4 grid (1024 x 1024, 256 per frame), read left to right, top to bottom.
# In Roblox: FlipbookLayout = Grid4x4, FlipbookMode = OneShot (the frames play once over each particle's life).
# ---------------------------------------------------------------------------------------------------------------
def value_noise(x, y, scale, seed):
    """Smooth 2D value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    n = int(scale) + 3
    g = rng.random((n, n))
    gx = (x + 1) / 2 * scale; gy = (y + 1) / 2 * scale
    x0 = np.floor(gx).astype(int); y0 = np.floor(gy).astype(int)
    fx = gx - x0; fy = gy - y0
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    def at(i, j):
        return g[np.clip(j, 0, n - 1), np.clip(i, 0, n - 1)]
    a = at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx
    b = at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx
    return a * (1 - fy) + b * fy


def save_flipbook(name, frame_fn, frames=16, cell=256):
    sheet = Image.new("RGBA", (cell * 4, cell * 4), (0, 0, 0, 0))
    for i in range(frames):
        t = i / (frames - 1)
        alpha, shade = frame_fn(t)
        a = np.clip(alpha, 0, 1)
        rgb = np.ones(a.shape) if shade is None else np.clip(shade, 0, 1)
        img = np.dstack([rgb, rgb, rgb, a])
        im = Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((cell, cell), Image.LANCZOS)
        sheet.paste(im, ((i % 4) * cell, (i // 4) * cell))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, name + ".png"))
    print("wrote", name, "(flipbook)")


def smoothstep(a, b, v):
    k = np.clip((v - a) / (b - a), 0, 1)
    return k * k * (3 - 2 * k)


def poof():
    """Cartoon smoke puff: a cluster of round lobes that swells fast, then breaks up and dissolves.
    Two-tone toon shading: the lit part is the same lobes nudged toward the light (top-left), so every lobe
    gets a clean shadow crescent on its bottom-right, like stylized game smoke."""
    x, y = grid(256)
    rng = np.random.default_rng(11)
    lobes = []
    for k in range(9):
        a = k / 9 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else rng.uniform(0.3, 0.46)
        lobes.append((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.26, 0.36) if k else 0.46))
    noise = value_noise(x, y, 6, 3) * 0.6 + value_noise(x, y, 15, 4) * 0.4

    def union(grow, dx, dy, shrink, lift):
        cov = np.zeros(x.shape)
        for cx, cy, r in lobes:
            dist = np.hypot(x - cx * grow - dx, y - cy * grow - lift - dy) - (r * grow - shrink)
            cov = np.maximum(cov, edge(dist, 0.012))
        return cov

    def frame(t):
        grow = 0.3 + 0.62 * (1 - (1 - min(1, t * 1.5)) ** 3)
        lift = 0.06 * t
        cover = union(grow, 0, 0, 0, lift)
        lit = union(grow, -0.07 * grow, 0.07 * grow, 0.03 * grow, lift)
        shade = 0.72 + 0.28 * lit
        thr = smoothstep(0.3, 1.0, t) * 1.05
        keep = edge(thr - noise, 0.03) if t > 0.25 else 1.0
        alpha = cover * keep * (1 - smoothstep(0.86, 1.0, t))
        return alpha, shade
    save_flipbook("poof", frame)


def impact():
    """Hit burst: a small hot core, a ring that races out and thins, and 8 long sharp spikes (comic style)
    that shoot out past the ring and taper away."""
    x, y = grid(256)
    r = np.hypot(x, y); th = np.arctan2(y, x)
    spikes = []
    rng = np.random.default_rng(5)
    for k in range(8):
        spikes.append((k / 8 * 2 * math.pi + rng.uniform(-0.15, 0.15), rng.uniform(0.8, 1.0)))

    def frame(t):
        e = 1 - (1 - t) ** 2.2
        core = edge(r - 0.2 * (1 - t) ** 2, 0.015) * (t < 0.45)
        R = 0.18 + 0.62 * e
        w = 0.07 * (1 - t) ** 1.5 + 0.004
        ring = edge(np.abs(r - R) - w, 0.012)
        rays = np.zeros(x.shape)
        for a, ln in spikes:
            da = np.angle(np.exp(1j * (th - a)))
            if t > 0.6:
                continue  # the spikes are the first instant; the ring carries the rest
            r0 = R + w * 0.5 if t > 0.12 else 0.05
            r1 = min(0.99, R + (0.2 + 0.18 * ln) * (1 - t * 0.6))
            u = np.clip((r - r0) / (r1 - r0), 0, 1)
            half = (0.09 * (1 - t / 0.6) ** 1.3 + 0.004) * (1 - u) ** 0.8  # width at the base, sharp tip
            d = np.abs(da) * r - half
            inside = edge(d, 0.01) * (r > r0) * (r < r1)
            rays = np.maximum(rays, inside)
        alpha = np.clip(core + ring + rays, 0, 1) * (1 - smoothstep(0.82, 1.0, t))
        return alpha, None
    save_flipbook("impact", frame)


def claw():
    """Three parallel swipe streaks with a soft glow (the trailer's white claw/blade streaks)."""
    x, y = grid(512)
    total = np.zeros(x.shape); shade = np.ones(x.shape) * 0.85
    for k, off in enumerate((-0.2, 0.0, 0.2)):
        r = np.hypot(x - 0.1 + off * 0.3, y + 0.7 + off)
        th = np.arctan2(y + 0.7 + off, x - 0.1 + off * 0.3)
        t = np.clip((th - math.radians(40)) / math.radians(95), 0, 1)
        along = np.where((th > math.radians(40)) & (th < math.radians(135)), np.sin(math.pi * t) ** 0.9, 0)
        c = 1.05
        width = 0.045 * along
        core = edge(np.abs(r - c) - width, 0.008) * (along > 0.03)
        glowv = np.exp(-((r - c) / 0.07) ** 2) * along * 0.45
        total = np.maximum(total, np.clip(core + glowv, 0, 1))
        shade = np.where(core > 0.5, 1.0, shade)
    save("claw", total, shade, n=512)


if __name__ == "__main__":
    for f in (glow, flare, burst, splinter, blade, smoke, ring, slash, spark, poof, impact, claw):
        f()
