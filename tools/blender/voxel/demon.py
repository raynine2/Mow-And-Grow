"""THE GLITCH DEMON (world 2's teaser boss, client/Demon) as a voxel sculpture.

Every body group (body, head, jaw, arms, forearms, wings) is sculpted with signed distance fields on its own voxel
grid in its own frame: its pivot at the origin, facing -Z, y up, in design units (about 42 from the waist to the
horn tips; client/Demon scales them to studs). Each group is coloured by material (shades picked by noise and lit
edges), then:
  * boxes: merged into as few boxes as possible (greedy; voxels hidden inside may join any box and the rest of the
    inside is left out: the shell is closed without it) for the part-built demon: src/client/DemonShape.luau, in
    two levels of detail (FULL, and LITE with bigger voxels for phones and "Potato" graphics)
  * voxels: a voxel dict per group (tools/blender/voxel/demon_preview.py renders it posed, in Blender)

    python3 tools/blender/voxel/demon.py luau        writes src/client/DemonShape.luau (needs numpy)

Pivots, tags and group names must match client/Demon: body (waist on the ground), head (top of the neck), jaw
(hinge, in the head), armL/armR (shoulders), foreL/foreR (elbows, in the arms), wingL/wingR (shoulder blades).
Tags: eye, eye3, grin, throat, core, pix (client/Demon drives them).
"""
import math
import os
import sys

import numpy as np

V = 0.5  # default voxel size, design units
HS = 1.25  # the head and jaw are sculpted in head units and scaled up by this
HEAD_PIVOT = (0.0, 18.0, 0.0)
JAW_PIVOT = (0.0, 1.1 * HS, 0.8 * HS)
EYES = (0.0, 5.05 * HS, -5.0 * HS)  # between the eyes, head space (client/Demon's close-ups aim here)

# ---------------------------------------------------------------------------------------------------------------
# palette: (r, g, b, neon, tag); index 0 is empty
# ---------------------------------------------------------------------------------------------------------------
PAL = [None]


def col(rgb, neon=False, tag=""):
    PAL.append((rgb[0], rgb[1], rgb[2], neon, tag))
    return len(PAL) - 1


SKIN = [col(c) for c in [(15, 8, 21), (23, 12, 31), (32, 18, 42), (43, 25, 56)]]
ARMOR = [col(c) for c in [(40, 19, 56), (52, 24, 71), (66, 31, 89), (84, 40, 112), (106, 52, 138)]]
HORN = [col(c) for c in [(40, 11, 28), (56, 14, 37), (76, 19, 48), (98, 23, 58), (124, 28, 70), (154, 36, 86)]]
BONE = [col(c) for c in [(190, 176, 208), (218, 206, 232), (242, 234, 250)]]
CLAW = [col(c) for c in [(12, 7, 18), (24, 13, 32)]]
SOCKET = col((5, 2, 9))
MOUTH = col((30, 4, 18))
NEON = col((255, 40, 170), True)
VEIN = col((176, 22, 112), True)
CYAN = col((60, 240, 255), True)
HOT = col((255, 120, 210), True, "core")
CORE_W = col((255, 226, 240), True, "core")
EYE = col((255, 52, 110), True, "eye")
EYE_W = col((255, 226, 240), True, "eye")
EYE3 = col((60, 240, 255), True, "eye3")
GRIN = col((255, 40, 130), True, "grin")
THROAT = col((255, 40, 170), True, "throat")
PIX = col((255, 40, 170), True, "pix")

# materials: lists of palette indices (shades, dark to light); one entry = a fixed colour
MATS = [None]


def mat(shades):
    MATS.append(list(shades))
    return len(MATS) - 1


M_SKIN = mat(SKIN)
M_ARMOR = mat(ARMOR)
M_BONE = mat(BONE)
M_CLAW = mat(CLAW)
M_SOCKET = mat([SOCKET])
M_MOUTH = mat([MOUTH])
M_NEON = mat([NEON])
M_VEIN = mat([VEIN])
M_CYAN = mat([CYAN])
M_HOT = mat([HOT])
M_COREW = mat([CORE_W])
M_EYE = mat([EYE])
M_EYEW = mat([EYE_W])
M_EYE3 = mat([EYE3])
M_GRIN = mat([GRIN])
M_THROAT = mat([THROAT])
M_PIX = mat([PIX])
M_HORN = [mat([h]) for h in HORN]

SHADE = dict(noise=1.0, fine=0.25, edge=0.6)


# ---------------------------------------------------------------------------------------------------------------
# signed distance primitives (P: (N, 3) points)
# ---------------------------------------------------------------------------------------------------------------
def A(v):
    return np.asarray(v, float)


def rot(ax=0.0, ay=0.0, az=0.0):
    """World-from-local rotation like Roblox's CFrame.Angles(ax, ay, az) (degrees): Rx * Ry * Rz."""
    a, b, c = math.radians(ax), math.radians(ay), math.radians(az)
    rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    ry = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return rx @ ry @ rz


def sphere(P, c, r):
    return np.linalg.norm(P - A(c), axis=1) - r


def ellipsoid(P, c, r, R=None):
    q = P - A(c)
    if R is not None:
        q = q @ R
    r = A(r)
    q = q / r
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / r, axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def box(P, c, half, R=None, rr=0.0):
    q = P - A(c)
    if R is not None:
        q = q @ R
    d = np.abs(q) - (A(half) - rr)
    return np.linalg.norm(np.maximum(d, 0), axis=1) + np.minimum(d.max(axis=1), 0) - rr


def cone(P, a, b, ra, rb):
    """A capsule whose radius runs from ra at a to rb at b."""
    a, b = A(a), A(b)
    ba = b - a
    l2 = max(ba @ ba, 1e-9)
    t = np.clip(((P - a) @ ba) / l2, 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ba), axis=1) - (ra + (rb - ra) * t)


def seg_dist(P, a, b):
    a, b = A(a), A(b)
    ba = b - a
    l2 = max(ba @ ba, 1e-9)
    t = np.clip(((P - a) @ ba) / l2, 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ba), axis=1)


def poly_dist(P, pts):
    d = np.full(len(P), 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, seg_dist(P, a, b))
    return d


def bez(p, t):
    p0, p1, p2, p3 = [A(q) for q in p]
    u = 1 - t
    return u ** 3 * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t ** 3 * p3


def hash3(ix, iy, iz, seed):
    n = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    n = (n ^ (n >> 13)) * 1274126177
    n = n ^ (n >> 16)
    return ((n & 0xFFFF) / 65535.0) * 2 - 1


def noise(P, freq, seed=1):
    """Smooth value noise in -1..1."""
    p = P * freq
    i = np.floor(p).astype(np.int64)
    f = p - i
    f = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


# ---------------------------------------------------------------------------------------------------------------
# a sculpt: one group's voxel grid. Its shapes are given in the group's own units; `sc` scales them up (the
# grid, the box output and the pivot of child groups are in scaled units).
# ---------------------------------------------------------------------------------------------------------------
class Sculpt:
    def __init__(self, name, lo, hi, pivot, parent=None, seed=1, sc=1.0, v=None):
        self.name, self.pivot, self.parent, self.seed, self.sc = name, pivot, parent, seed, sc
        self.v = v or V
        self.lo = np.floor(A(lo) * sc / self.v) * self.v
        hi = np.ceil(A(hi) * sc / self.v) * self.v
        self.n = np.round((hi - self.lo) / self.v).astype(int)
        g = np.meshgrid(*[np.arange(k) for k in self.n], indexing="ij")
        self.idx = np.stack(g, -1).reshape(-1, 3)
        self.Pw = self.lo + (self.idx + 0.5) * self.v
        self.P = self.Pw / sc  # in the group's own units
        self.D = np.full(len(self.P), 1e9)  # scaled units
        self.M = np.zeros(len(self.P), int)

    def add(self, d, m, k=0.0):
        d = d * self.sc
        k = k * self.sc
        if k > 0:
            h = np.clip(0.5 + 0.5 * (self.D - d) / k, 0, 1)
            nd = d * h + self.D * (1 - h) - k * h * (1 - h)
        else:
            nd = np.minimum(self.D, d)
        self.M = np.where(d < self.D, m, self.M)
        self.D = nd

    def carve(self, d, m=None):
        d = d * self.sc
        nd = np.maximum(self.D, -d)
        if m is not None:
            wall = (-d >= self.D - 0.05) & (nd <= 0) & (nd > -1.6 * self.v)
            self.M = np.where(wall, m, self.M)
        self.D = nd

    def paint(self, mask, m, depth=None):
        sel = mask & (self.D <= 0)
        if depth is not None:
            sel = sel & (self.D > -depth * self.sc)
        self.M = np.where(sel, m, self.M)

    def _probe(self, x, y, zs):
        P = np.stack([np.full_like(zs, x), np.full_like(zs, y), zs], 1) * self.sc
        i = np.floor((P - self.lo) / self.v).astype(int)
        ok = np.all((i >= 0) & (i < self.n), axis=1)
        flat = np.where(ok, (i[:, 0] * self.n[1] + i[:, 1]) * self.n[2] + i[:, 2], 0)
        inside = ok & (self.D[flat] <= 0)
        k = int(np.argmax(inside))
        return zs[k] if inside[k] else None

    def front(self, x, y):
        """The z where the solid starts, coming from the front (-z), at (x, y) (own units)."""
        return self._probe(x, y, np.arange(-14.0, 14.0, 0.08))

    def back(self, x, y):
        return self._probe(x, y, np.arange(14.0, -14.0, -0.08))

    # -- results --------------------------------------------------------------------------------------------
    def grid(self):
        """Palette index per voxel (nx, ny, nz), shaded, and how many faces each voxel shows."""
        solid = self.D <= 0
        mg = np.zeros(tuple(self.n), int)
        mg[tuple(self.idx[solid].T)] = self.M[solid]
        occ = mg > 0
        pad = np.pad(occ, 1)
        nbs = [pad[2:, 1:-1, 1:-1], pad[:-2, 1:-1, 1:-1], pad[1:-1, 2:, 1:-1], pad[1:-1, :-2, 1:-1], pad[1:-1, 1:-1, 2:], pad[1:-1, 1:-1, :-2]]
        exposed = sum((~n).astype(int) for n in nbs) * occ
        shape = tuple(self.n)
        nz = noise(self.Pw, 0.42 / self.sc, self.seed).reshape(shape)
        nz2 = noise(self.Pw, 1.3 / self.sc, self.seed + 7).reshape(shape)
        out = np.zeros(shape, int)
        for mid in range(1, len(MATS)):
            sel = mg == mid
            if not sel.any():
                continue
            shades = MATS[mid]
            k = len(shades)
            if k == 1:
                out[sel] = shades[0]
                continue
            base = (k - 1) * 0.45 + nz[sel] * SHADE["noise"] + nz2[sel] * SHADE["fine"] + (exposed[sel] >= 2) * SHADE["edge"]
            i = np.clip(np.round(base), 0, k - 1).astype(int)
            out[sel] = np.array(shades)[i]
        return out, exposed

    def origin_index(self):
        """Grid index of the cell whose min corner is the pivot (lo is a multiple of the voxel size)."""
        return np.round(-self.lo / self.v).astype(int)


def greedy(cg, exposed):
    """Boxes (x, y, z, sx, sy, sz, colour) in grid cells. Each visible voxel is in exactly one box of its colour;
    hidden voxels may join any box; leftover hidden voxels are dropped (the shell is closed without them)."""
    nx, ny, nz = cg.shape
    done = np.zeros(cg.shape, bool)
    hidden = (exposed == 0) & (cg > 0)
    boxes = []
    for y in range(ny):
        for z in range(nz):
            for x in range(nx):
                c = cg[x, y, z]
                if c == 0 or done[x, y, z] or hidden[x, y, z]:
                    continue

                def ok(sl):
                    return bool(np.all((~done[sl]) & ((cg[sl] == c) | hidden[sl])))

                x1 = x
                while x1 + 1 < nx and ok((slice(x1 + 1, x1 + 2), y, z)):
                    x1 += 1
                z1 = z
                while z1 + 1 < nz and ok((slice(x, x1 + 1), y, z1 + 1)):
                    z1 += 1
                y1 = y
                while y1 + 1 < ny and ok((slice(x, x1 + 1), y1 + 1, slice(z, z1 + 1))):
                    y1 += 1
                done[x : x1 + 1, y : y1 + 1, z : z1 + 1] = True
                boxes.append((x, y, z, x1 - x + 1, y1 - y + 1, z1 - z + 1, int(c)))
    return boxes


# ---------------------------------------------------------------------------------------------------------------
# the design
# ---------------------------------------------------------------------------------------------------------------
def surface_line(S, pts2, depth=0.6, width=0.32, m=M_NEON):
    """Paint a line on the front surface through 2D points (x, y): each point is dropped onto the surface."""
    pts = []
    for x, y in pts2:
        z = S.front(x, y)
        if z is not None:
            pts.append((x, y, z + 0.15))
    if len(pts) >= 2:
        S.paint(poly_dist(S.P, pts) < width + 0.25, m, depth)


def body(v=None):
    S = Sculpt("body", (-17.5, -4.5, -8.5), (17.5, 23.5, 11.5), (0, 0, 0), seed=11, v=v)
    P = S.P
    # waist, belly, chest, back and the heavy trapezius that hunches up to the neck
    S.add(ellipsoid(P, (0, 1.2, 0.4), (5.8, 6.0, 4.4)), M_SKIN)
    S.add(ellipsoid(P, (0, 6.4, 0.1), (7.4, 4.6, 4.9)), M_SKIN, 1.5)
    S.add(box(P, (0, 11.2, 0.2), (8.3, 3.6, 4.7), rr=1.8), M_SKIN, 1.5)
    S.add(ellipsoid(P, (0, 10.4, 2.6), (8.8, 6.2, 3.6)), M_SKIN, 1.2)
    for s in (-1, 1):
        S.add(ellipsoid(P, (s * 6.6, 14.6, 1.0), (5.0, 2.9, 4.2)), M_SKIN, 2.0)
    S.add(cone(P, (0, 14.2, 0.7), (0, 19.0, 0.4), 3.4, 2.8), M_SKIN, 1.2)
    # pectoral armour, a groove down the sternum
    for s in (-1, 1):
        S.add(ellipsoid(P, (s * 3.9, 11.4, -2.6), (4.3, 3.3, 2.5), rot(0, s * -12, s * 8)), M_ARMOR, 0.6)
    S.carve(box(P, (0, 11.0, -5.6), (0.35, 3.6, 1.6)), M_SOCKET)
    # abdominal plates in three rows, each pair split down the middle
    for y in (1.0, 3.3, 5.6):
        for s in (-1, 1):
            x = s * 1.95
            z = S.front(x, y)
            if z is None:
                continue
            S.add(box(P, (x, y, z + 0.35), (1.65, 0.95, 0.75), rot(-8, s * -10, 0), rr=0.35), M_ARMOR, 0.25)
    # ribs round the flanks
    for y in (6.0, 7.7, 9.4):
        for s in (-1, 1):
            S.add(cone(P, (s * 5.6, y, -3.4), (s * 8.0, y - 0.5, 1.6), 0.55, 0.45), M_ARMOR, 0.3)
    # the core in the sternum: a socket with a hot heart, and cracks running out of it
    z = S.front(0.0, 10.2) or -5.0
    S.carve(sphere(P, (0, 10.2, z - 0.4), 1.9), M_SOCKET)
    S.add(sphere(P, (0, 10.2, z + 0.6), 1.25), M_HOT)
    S.add(sphere(P, (0, 10.2, z + 0.1), 0.6), M_COREW)
    cracks = [
        [(0.6, 11.7), (1.4, 12.9), (1.1, 13.8), (2.4, 15.0)],
        [(-0.7, 11.6), (-1.9, 12.4), (-2.6, 13.9), (-4.1, 14.4)],
        [(1.3, 9.4), (2.9, 8.6), (3.4, 7.2), (5.0, 6.4), (5.6, 5.0)],
        [(-1.2, 9.2), (-2.4, 8.1), (-2.1, 6.6), (-3.3, 5.2)],
        [(0.2, 8.8), (0.5, 7.4), (-0.3, 6.2), (0.4, 4.6), (-0.2, 3.0)],
        [(3.0, 12.4), (4.6, 12.0), (5.9, 12.9)],
    ]
    for c in cracks:
        surface_line(S, c, depth=0.7, width=0.18)
    # corrupted pixels on the plates (tag pix: they flicker and swap colour)
    for x, y in [(-5.4, 11.0), (3.1, 8.9), (5.8, 12.8), (-2.7, 4.6), (4.2, 1.5), (-6.4, 13.4), (2.2, 13.6)]:
        z = S.front(x, y)
        if z is not None:
            S.add(box(P, (x, y, z - 0.05), (0.45, 0.45, 0.3)), M_PIX)
    # spine: a ridge of spikes down the back, biggest between the shoulders
    for i in range(7):
        y = 2.2 + i * 2.25
        zb = S.back(0.0, y)
        if zb is None:
            continue
        h = 1.6 + 2.2 * math.sin((i + 1) / 8 * math.pi)
        base = (0, y, zb - 0.4)
        tip = (0, y + h * 0.55, zb + h)
        S.add(cone(P, base, tip, 1.0, 0.12), M_HORN[2 if i % 2 else 3], 0.3)
        S.paint(sphere(P, tip, 0.45) < 0, M_NEON)
    # pauldrons: three overlapping armour plates per shoulder, a neon rim on each, three horn spikes on top
    for s in (-1, 1):
        plates = [((s * 11.3, 15.5, 0.3), (4.6, 2.7, 5.2), 6), ((s * 12.5, 13.6, 0.3), (3.9, 2.3, 4.7), 14), ((s * 13.3, 11.9, 0.3), (3.0, 1.9, 4.0), 22)]
        for c, r, tilt in plates:
            S.add(ellipsoid(P, c, r, rot(0, 0, s * tilt)), M_ARMOR, 0.2)
            rim = ellipsoid(P, (c[0], c[1] - 0.35, c[2]), (r[0] + 0.25, r[1] * 0.55, r[2] + 0.25), rot(0, 0, s * tilt))
            S.add(np.maximum(rim, P[:, 1] - (c[1] - r[1] * 0.42)), M_ARMOR, 0.0)
            band = (np.abs(P[:, 1] - (c[1] - r[1] * 0.5)) < 0.3) & (ellipsoid(P, c, (r[0] + 0.4, r[1] + 0.4, r[2] + 0.4), rot(0, 0, s * tilt)) < 0)
            S.paint(band, M_NEON, depth=0.8)
        for i, dz in enumerate((-2.6, 0.0, 2.6)):
            base = (s * (10.4 + i * 0.5 + (0.3 if dz == 0 else 0)), 17.4, dz)
            length = 4.6 if dz == 0 else 3.6
            tip = (base[0] + s * length * 0.45, base[1] + length, base[2] + length * 0.12)
            S.add(cone(P, base, tip, 1.05, 0.12), M_HORN[3], 0.25)
            mid = tuple((A(base) + A(tip)) / 2)
            S.add(cone(P, base, mid, 1.15, 0.85), M_HORN[1], 0.2)
            S.paint(sphere(P, tip, 0.55) < 0, M_NEON)
    # glowing veins over the belly and flanks (dim neon)
    for c in [[(-4.6, 2.0), (-5.6, 4.0), (-5.0, 6.0), (-6.4, 8.0)], [(4.4, 2.6), (5.8, 4.4), (5.2, 6.4)]]:
        surface_line(S, c, depth=0.5, width=0.12, m=M_VEIN)
    return S


def head(v=None):
    S = Sculpt("head", (-12.0, -1.6, -8.4), (12.0, 21.0, 6.0), HEAD_PIVOT, "body", seed=23, sc=HS, v=v)
    P = S.P
    # cranium and the boxy brow-to-jaw block of the face
    S.add(ellipsoid(P, (0, 5.4, 0.6), (4.6, 4.1, 4.9)), M_SKIN)
    S.add(box(P, (0, 4.5, -1.3), (4.2, 3.0, 3.6), rr=1.3), M_SKIN, 1.0)
    # the snout (upper jaw), a ridge up to the brow, two nostril slits
    S.add(ellipsoid(P, (0, 2.5, -4.3), (3.4, 1.9, 2.8)), M_SKIN, 0.9)
    S.add(box(P, (0, 3.6, -5.0), (1.0, 0.7, 1.9), rot(14, 0, 0), rr=0.4), M_ARMOR, 0.4)
    for s in (-1, 1):
        S.carve(box(P, (s * 0.85, 2.85, -6.8), (0.28, 0.42, 0.6), rot(0, 0, s * -25)), M_SOCKET)
    # cheekbones and the jaw muscles
    for s in (-1, 1):
        S.add(ellipsoid(P, (s * 3.7, 3.5, -3.7), (1.5, 1.05, 1.5)), M_ARMOR, 0.5)
        S.add(ellipsoid(P, (s * 3.9, 2.4, -0.8), (1.3, 1.8, 2.2)), M_SKIN, 0.8)
    # the scowl: two heavy brow plates sloping down to meet over the snout
    for s in (-1, 1):
        S.add(box(P, (s * 2.45, 6.5, -4.55), (2.6, 0.72, 1.15), rot(0, -s * 14, s * 17), rr=0.35), M_ARMOR, 0.45)
    # deep eye sockets under the brow with big burning slanted eyes in them (low at the inside), white-hot slits
    for s in (-1, 1):
        S.carve(ellipsoid(P, (s * 2.3, 5.05, -5.0), (1.75, 1.0, 1.2), rot(0, 0, s * 18)), M_SOCKET)
        S.add(box(P, (s * 2.3, 5.0, -4.5), (1.5, 0.46, 0.35), rot(0, 0, s * 18)), M_EYE)
        S.add(box(P, (s * 2.15, 4.95, -4.75), (0.8, 0.2, 0.25), rot(0, 0, s * 18)), M_EYEW)
    # the third eye, a cyan diamond above the scowl
    zf = S.front(0.0, 7.7) or -4.6
    S.add(box(P, (0, 7.75, zf + 0.05), (0.6, 0.6, 0.35), rot(0, 0, 45)), M_EYE3)
    # a crest along the top of the skull with three spikes, and swept-back fins over the ears
    S.add(cone(P, (0, 8.9, -2.8), (0, 9.6, 3.4), 0.95, 0.55), M_ARMOR, 0.5)
    for i, zc in enumerate((-1.6, 0.6, 2.8)):
        S.add(cone(P, (0, 9.6 + i * 0.15, zc), (0, 11.0 - i * 0.2, zc + 1.2), 0.5, 0.1), M_HORN[3], 0.15)
    for s in (-1, 1):
        S.add(cone(P, (s * 4.3, 5.6, 0.6), (s * 6.5, 7.9, 3.8), 0.85, 0.12), M_HORN[2], 0.3)
        S.add(cone(P, (s * 4.2, 4.6, 1.0), (s * 6.0, 5.6, 4.3), 0.65, 0.1), M_HORN[1], 0.3)
    # the horns: out from the temples, up, a little back, then hooking in; banded, darkening to a neon tip
    for s in (-1, 1):
        pts = [(s * 3.9, 7.3, 0.2), (s * 9.0, 8.8, 0.9), (s * 10.6, 14.4, 2.4), (s * 7.2, 18.6, 0.4)]
        n = 30
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            a, b = bez(pts, t0), bez(pts, t1)
            ra, rb = 1.45 * (1 - t0) ** 0.85 + 0.16, 1.45 * (1 - t1) ** 0.85 + 0.16
            band = int(t0 * 5.99)
            m = M_HORN[min(5, band)] if (i % 5) != 4 else M_HORN[max(0, band - 2)]
            S.add(cone(P, a, b, ra, rb), m, 0.12)
        S.paint(sphere(P, bez(pts, 1.0), 0.75) < 0, M_NEON)
    # the mouth: the snout's underside hollowed, nine upper teeth (fangs at the corners), the grin glowing behind
    S.carve(box(P, (0, 0.55, -4.6), (2.7, 0.62, 2.0), rr=0.3), M_MOUTH)
    for i in range(9):
        x = -2.8 + i * 0.7
        fang = i in (0, 8)
        h = 2.0 if fang else (1.1 if i % 2 else 0.85)
        zz = -6.15 + 0.07 * x * x
        S.add(cone(P, (x, 1.25, zz), (x, 1.25 - h, zz + 0.1), 0.42 if fang else 0.3, 0.07), M_BONE, 0.04)
    S.add(box(P, (0, 0.62, -5.45), (2.6, 0.62, 0.22)), M_GRIN)
    # glitch corruption over its left cheek and temple: pixels torn out (glowing veins under them) and stuck on
    region = (P[:, 0] > 1.2) & (P[:, 1] > 1.8) & (P[:, 1] < 8.6) & (P[:, 2] < -0.5)
    nz = noise(P, 1.1, 77)
    surface = (S.D <= 0) & (S.D > -0.5)
    deep = (S.D <= -0.5) & (S.D > -1.1)
    torn = region & (nz > 0.5)
    rim = region & (nz > 0.3) & ~torn
    S.M = np.where(rim & surface, M_VEIN, S.M)
    S.M = np.where(torn & deep, M_VEIN, S.M)
    S.D = np.where(torn & surface, 0.1, S.D)
    pix = region & surface & (nz < -0.45) & (noise(P, 2.3, 78) > 0.1)
    S.M = np.where(pix, M_PIX, S.M)
    return S


def jaw(v=None):
    S = Sculpt("jaw", (-4.5, -3.6, -8.0), (4.5, 3.2, 2.0), JAW_PIVOT, "head", seed=31, sc=HS, v=v)
    P = S.P
    S.add(ellipsoid(P, (0, -0.9, -3.4), (3.2, 1.25, 3.3)), M_SKIN)
    S.add(box(P, (0, -0.7, -1.0), (3.3, 1.0, 1.7), rr=0.6), M_SKIN, 0.8)
    S.add(ellipsoid(P, (0, -1.4, -5.8), (1.7, 1.05, 1.1)), M_ARMOR, 0.6)  # chin
    for s in (-1, 1):
        S.add(cone(P, (s * 0.9, -2.0, -5.9), (s * 1.4, -3.3, -6.7), 0.42, 0.08), M_BONE, 0.1)  # chin spikes
    # hollow the mouth floor, the glowing throat in it, the lower teeth along the front (fangs at the corners)
    S.carve(box(P, (0, 0.3, -3.3), (2.3, 0.5, 2.3), rr=0.3), M_MOUTH)
    S.add(box(P, (0, -0.1, -3.2), (2.1, 0.12, 2.0)), M_THROAT)
    for i in range(7):
        x = -2.3 + i * 0.77
        fang = i in (0, 6)
        h = 1.8 if fang else (1.0 if i % 2 else 0.8)
        zz = -5.75 + 0.07 * x * x
        S.add(cone(P, (x, -0.1, zz), (x, -0.1 + h, zz - 0.1), 0.4 if fang else 0.3, 0.07), M_BONE, 0.04)
    return S


def arm(side, v=None):
    S = Sculpt("armL" if side < 0 else "armR", (-4.0, -10.5, -4.0), (4.0, 3.5, 6.0), (side * 11.2, 13.4, 0), "body", seed=41 + side, v=v)
    P = S.P
    S.add(sphere(P, (0, 0, 0), 2.6), M_SKIN)
    S.add(cone(P, (0, -0.5, 0), (0, -8.3, 0.3), 2.5, 2.1), M_SKIN, 0.8)
    S.add(ellipsoid(P, (0, -3.6, -1.1), (2.2, 2.9, 1.8)), M_SKIN, 0.9)  # biceps
    S.add(ellipsoid(P, (0, -4.6, 1.3), (2.0, 3.0, 1.5)), M_SKIN, 0.9)  # triceps
    # an armour band round the arm with a neon trim
    S.add(box(P, (0, -5.6, 0), (2.75, 0.75, 2.75), rr=0.6), M_ARMOR, 0.2)
    S.paint(np.abs(P[:, 1] + 6.25) < 0.22, M_NEON, depth=0.6)
    S.add(cone(P, (0, -7.9, 1.9), (0, -8.8, 4.8), 0.75, 0.12), M_HORN[3], 0.2)  # elbow spike
    zf = S.front(side * 0.6, -2.4) or -2.0
    S.add(box(P, (side * 0.6, -2.4, zf), (0.45, 0.45, 0.3)), M_PIX)
    return S


def fore(side, v=None):
    S = Sculpt("foreL" if side < 0 else "foreR", (-4.5, -15.0, -6.0), (4.5, 3.0, 4.0), (0, -8.6, 0), "armL" if side < 0 else "armR", seed=51 + side, v=v)
    P = S.P
    S.add(sphere(P, (0, 0, 0), 2.2), M_SKIN)
    S.add(cone(P, (0, -0.3, -0.2), (0, -6.4, -0.6), 2.3, 2.75), M_SKIN, 0.8)
    # the bracer: plated, runed in neon, spikes out the side
    S.add(box(P, (0, -3.9, -0.5), (2.95, 2.1, 2.95), rr=0.8), M_ARMOR, 0.3)
    S.paint((np.abs(P[:, 1] + 2.45) < 0.2) | (np.abs(P[:, 1] + 5.35) < 0.2), M_NEON, depth=0.6)
    surface_line(S, [(-0.8, -2.9), (0.4, -3.5), (-0.5, -4.2), (0.7, -4.9)], depth=0.6, width=0.14)
    for y in (-3.1, -4.7):
        S.add(cone(P, (side * 2.6, y, -0.4), (side * 4.3, y + 0.9, 0.6), 0.6, 0.1), M_HORN[3], 0.15)
    # the hand, knuckles, four long fingers curling into hooked claws with neon tips, and a thumb
    S.add(box(P, (0, -7.9, -0.9), (2.6, 1.5, 2.3), rr=0.75), M_SKIN, 0.6)
    for i, x in enumerate((-1.85, -0.62, 0.62, 1.85)):
        S.add(sphere(P, (x, -8.9, -2.3), 0.62), M_ARMOR, 0.2)
        L = 1.3 if i in (0, 3) else 1.7
        k1 = (x, -8.9, -2.4)
        k2 = (x * 1.05, -8.9 - L, -3.4)
        S.add(cone(P, k1, k2, 0.55, 0.47), M_SKIN, 0.15)
        pts = [k2, (x * 1.08, k2[1] - 1.2, -4.0), (x * 1.1, k2[1] - 2.4, -3.8), (x * 1.1, k2[1] - 3.0, -2.8)]
        n = 6
        for j in range(n):
            a, b = bez(pts, j / n), bez(pts, (j + 1) / n)
            S.add(cone(P, a, b, 0.47 - 0.36 * j / n, 0.47 - 0.36 * (j + 1) / n), M_CLAW, 0.06)
        S.paint(sphere(P, bez(pts, 1.0), 0.5) < 0, M_NEON)
    th0, th1, th2 = (-side * 2.3, -7.4, -1.6), (-side * 3.1, -9.0, -3.2), (-side * 2.6, -10.2, -4.0)
    S.add(cone(P, th0, th1, 0.7, 0.5), M_SKIN, 0.3)
    S.add(cone(P, th1, th2, 0.5, 0.1), M_CLAW, 0.1)
    S.paint(sphere(P, th2, 0.4) < 0, M_NEON)
    return S


def wing(side, v=None):
    lo = (-2.5, -2.5, -2.5) if side > 0 else (-22.5, -2.5, -2.5)
    hi = (22.5, 22.5, 9.0) if side > 0 else (2.5, 22.5, 9.0)
    S = Sculpt("wingL" if side < 0 else "wingR", lo, hi, (side * 5.5, 13, 4.6), "body", seed=61 + side, v=v)
    P = S.P
    # four bony spines fanned up and out, a little back, tipped in neon
    tips = []
    for i, (ang, ln) in enumerate([(20, 21.0), (40, 19.5), (60, 16.5), (80, 12.5)]):
        a = math.radians(ang)
        tip = (side * math.sin(a) * ln, math.cos(a) * ln, 1.4 + i * 1.3)
        mid = (tip[0] * 0.55, tip[1] * 0.55 + 0.8, tip[2] * 0.45)
        S.add(cone(P, (0, 0, 0), mid, 1.05, 0.68), M_HORN[1], 0.3)
        S.add(cone(P, mid, tip, 0.68, 0.14), M_HORN[2], 0.2)
        S.add(sphere(P, mid, 0.85), M_HORN[3], 0.2)  # a knuckle halfway
        S.paint(sphere(P, tip, 0.6) < 0, M_NEON)
        tips.append(np.array(tip))
    # torn membrane between them: thin, scalloped between the tips, holed by the glitch; neon along the edge
    root = np.zeros(3)
    for j, (a, b) in enumerate(zip(tips[:-1], tips[1:])):
        nrm = np.cross(a - root, b - root)
        nrm /= np.linalg.norm(nrm)
        dist = np.abs((P - root) @ nrm)
        v0, v1, v2 = a - root, b - root, P - root
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        inside = (bv >= -0.02) & (bw >= -0.02) & (bv + bw <= 1.02)
        mid = (a + b) / 2
        rcut = np.linalg.norm(a - b) * 0.42
        dc = np.linalg.norm(P - mid * 0.98, axis=1)
        holes = noise(P, 0.75, 90 + j) > 0.42
        memb = inside & (dist < 0.32) & (dc >= rcut) & ~holes
        S.add(np.where(memb, -0.1, 1.0), M_SKIN)
        S.paint(memb & (dc < rcut + 0.6), M_NEON)
    return S


def groups(v=None, vhead=None):
    return [
        body(v), head(vhead or v), jaw(vhead or v),
        arm(-1, v), arm(1, v), fore(-1, v), fore(1, v), wing(-1, v), wing(1, v),
    ]


# ---------------------------------------------------------------------------------------------------------------
# output
# ---------------------------------------------------------------------------------------------------------------
GHOSTS = 90  # the biggest boxes of each level also get red / cyan ghost copies in the glitches


# boxes are written 7 characters each (x, y, z, sx, sy, sz, colour) in this alphabet (value = position): x, y, z
# count grid cells from the group's grid corner (ORIGIN is the pivot's cell), colour + GHOST marks a ghost box
ALPHA = "".join(chr(c) for c in range(35, 127) if chr(c) not in "\\]")  # (no "]": the data sits in [[ ]] strings)
GHOST = 45


def check(cg, exposed, boxes):
    """Every visible voxel in exactly one box of its colour, no box over an empty cell."""
    cover = np.zeros(cg.shape, int)
    colour = np.zeros(cg.shape, int)
    for (x, y, z, sx, sy, sz, c) in boxes:
        sl = (slice(x, x + sx), slice(y, y + sy), slice(z, z + sz))
        assert np.all(cg[sl] > 0), "box over an empty cell"
        cover[sl] += 1
        colour[sl] = c
    vis = exposed > 0
    assert np.all(cover[vis] == 1), "visible voxel not covered exactly once"
    assert np.all(colour[vis] == cg[vis]), "visible voxel in a box of another colour"
    assert np.all(cover <= 1)


def encode(boxes, ghost):
    out = []
    for (x, y, z, sx, sy, sz, c), g in zip(boxes, ghost):
        vals = (x, y, z, sx, sy, sz, c + (GHOST if g else 0))
        assert max(vals) < len(ALPHA) and c < GHOST
        out.append("".join(ALPHA[v] for v in vals))
    return out


def luau_level(lines, name, built):
    lines.append("Shape.%s = {" % name)
    total = 0
    per = []
    vols = []
    for S, cg, exposed in built:
        boxes = greedy(cg, exposed)
        check(cg, exposed, boxes)
        per.append(boxes)
        vols += [b[3] * b[4] * b[5] * S.v ** 3 if not PAL[b[6]][3] else 0 for b in boxes]
    cut = sorted(vols, reverse=True)[GHOSTS - 1]
    for (S, cg, exposed), boxes in zip(built, per):
        ghost = [(b[3] * b[4] * b[5] * S.v ** 3 >= cut and not PAL[b[6]][3]) for b in boxes]
        items = encode(boxes, ghost)
        total += len(items)
        s = "".join(items)
        o = S.origin_index()
        lines.append("\t{")
        lines.append('\t\tname = "%s", voxel = %s, origin = Vector3.new(%d, %d, %d),' % (S.name, repr(float(S.v)), o[0], o[1], o[2]))
        lines.append("\t\tpivot = Vector3.new(%s, %s, %s)," % tuple(repr(round(float(c), 4)) for c in S.pivot))
        lines.append("\t\tparent = %s," % ('"%s"' % S.parent if S.parent else "nil"))
        lines.append("\t\tboxes = table.concat({")
        for i in range(0, len(s), 112):
            lines.append("\t\t\t[[%s]]," % s[i : i + 112])
        lines.append("\t\t}),")
        lines.append("\t},")
        print("  %-6s v=%.2f voxels %6d  boxes %5d" % (S.name, S.v, int((cg > 0).sum()), len(items)))
    lines.append("}")
    print("%s: %d boxes, ghosts on boxes of %.1f units^3 and up" % (name, total, cut))


def luau(path, full=(0.75, 0.5), lite=(1.0, 0.75)):
    lines = [
        "-- GENERATED by tools/blender/voxel/demon.py (python3 tools/blender/voxel/demon.py luau). Don't edit by hand:",
        "-- change the sculpture there and run it again. The glitch demon's shape for client/Demon, in two levels of",
        "-- detail (FULL; LITE for phones and Potato graphics). Per group, `boxes` holds 7 characters per box: the min",
        "-- corner x, y, z (grid cells; `origin` is the pivot's cell), the size sx, sy, sz (cells of `voxel` design units)",
        "-- and the colour (PALETTE index; + GHOST for a big box that also gets red / cyan ghosts in the glitches), each",
        "-- character's value being its position in ALPHA (0-based).",
        "local Shape = {}",
        "Shape.ALPHA = [[%s]]" % ALPHA,
        "Shape.GHOST = %d" % GHOST,
        "Shape.EYES = Vector3.new(%s, %s, %s) -- between the eyes, in the head's space" % tuple(repr(round(c, 4)) for c in EYES),
        "-- { r, g, b, neon, tag }",
        "Shape.PALETTE = {",
    ]
    for e in PAL[1:]:
        r, g, b, neon, tag = e
        lines.append("\t{ %d, %d, %d, %s, %s }," % (r, g, b, "true" if neon else "false", '"%s"' % tag if tag else "nil"))
    lines.append("}")
    for name, (v, vh) in (("FULL", full), ("LITE", lite)):
        built = []
        for S in groups(v, vh):
            cg, exposed = S.grid()
            built.append((S, cg, exposed))
        luau_level(lines, name, built)
    lines.append("return Shape")
    open(path, "w").write("\n".join(lines) + "\n")
    print("->", path, os.path.getsize(path), "bytes")


def voxels(v=None, vhead=None):
    """[(Sculpt, {(x, y, z): palette index})] with keys in voxels from the pivot."""
    res = []
    for S in groups(v, vhead):
        cg, exposed = S.grid()
        o = S.origin_index()
        nzs = np.argwhere(cg > 0)
        vox = {(int(i - o[0]), int(j - o[1]), int(k - o[2])): int(cg[i, j, k]) for i, j, k in nzs}
        res.append((S, vox))
    return res


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "luau":
        here = os.path.dirname(os.path.abspath(__file__))
        luau(os.path.join(here, "..", "..", "..", "src", "client", "DemonShape.luau"))
