"""Voxel sculpting kit: models sculpted with signed distance fields on voxel grids, shaded, merged into boxes and
written as Luau shape data that the game builds from parts (shared/SculptKit). The glitch demon
(tools/blender/voxel/demon.py) was the first; the Mayor, the gas pump and the bags use this kit
(tools/blender/voxel/sculpts.py).

A model is a list of groups (one for a prop; several for a figure whose parts move: body, head, arms). Each group
is sculpted on its own grid in its own frame: its pivot at the origin, front toward -Z, y up, in studs (or design
units the game scales). Shapes are added with `add(distance, material, blend)`, cut with `carve`, coloured with
`paint`; materials are lists of palette shades (dark to light) picked per voxel by noise and lit edges.
Boxes: greedy merge; hidden voxels may join any box and the rest of the inside is left out (the shell is closed).
"""
import math
import os

import numpy as np

ALPHA = "".join(chr(c) for c in range(35, 127) if chr(c) not in "\\]")  # (no "]": the data sits in [[ ]] strings)


# ---------------------------------------------------------------------------------------------------------------
# palette: colours with a Roblox material and an optional tag; materials are lists of shades
# ---------------------------------------------------------------------------------------------------------------
class Palette:
    def __init__(self):
        self.entries = [None]  # (r, g, b, material, tag)
        self.mats = [None]
        self.mshade = [None]  # per-material shading overrides (see Sculpt.grid)

    def col(self, rgb, material="SmoothPlastic", tag=""):
        self.entries.append((int(rgb[0]), int(rgb[1]), int(rgb[2]), material, tag))
        return len(self.entries) - 1

    def mat(self, shades, material="SmoothPlastic", tag="", **shade):
        """A material from a list of rgb shades (dark to light) or palette indices. Keyword arguments override the
        group's shading for this material (noise, fine, edge, base, ao, top)."""
        idx = [s if isinstance(s, int) else self.col(s, material, tag) for s in shades]
        self.mats.append(idx)
        self.mshade.append(shade)
        return len(self.mats) - 1


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


def cyl(P, a, b, r, rr=0.0):
    """A flat-ended cylinder from a to b, radius r (edges rounded by rr)."""
    a, b = A(a), A(b)
    ba = b - a
    L = np.linalg.norm(ba)
    u = ba / max(L, 1e-9)
    q = P - (a + b) / 2
    h = q @ u
    rad = np.linalg.norm(q - h[:, None] * u, axis=1)
    d = np.stack([rad - (r - rr), np.abs(h) - (L / 2 - rr)], 1)
    return np.linalg.norm(np.maximum(d, 0), axis=1) + np.minimum(d.max(axis=1), 0) - rr


def torus(P, c, R, r, Rot=None):
    """A ring in the local XZ plane (axis = local Y)."""
    q = P - A(c)
    if Rot is not None:
        q = q @ Rot
    xz = np.linalg.norm(q[:, [0, 2]], axis=1) - R
    return np.sqrt(xz * xz + q[:, 1] ** 2) - r


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


def tube(S, pts, r0, r1, m, n=16, k=0.08):
    """A tapering tube along a cubic bezier (4 points), radius r0 -> r1."""
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        S.add(cone(S.P, bez(pts, t0), bez(pts, t1), r0 + (r1 - r0) * t0, r0 + (r1 - r0) * t1), m, k)


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
# a sculpt: one group's voxel grid
# ---------------------------------------------------------------------------------------------------------------
class Sculpt:
    def __init__(self, pal, name, lo, hi, v, pivot=(0, 0, 0), parent=None, seed=1, shade=None, phase=0.0):
        """`phase` 0.5 shifts the grid half a voxel off the pivot, so two groups that overlap at a joint never
        have voxel faces in the same plane (which would flicker)."""
        self.pal, self.name, self.pivot, self.parent, self.seed, self.v = pal, name, pivot, parent, seed, v
        self.shade = shade or dict(noise=0.8, fine=0.2, edge=0.6, base=0.45, freq=0.6)
        self.phase = phase
        self.lo = (np.floor(A(lo) / v - phase) + phase) * v
        hi = (np.ceil(A(hi) / v - phase) + phase) * v
        self.n = np.round((hi - self.lo) / v).astype(int)
        g = np.meshgrid(*[np.arange(k) for k in self.n], indexing="ij")
        self.idx = np.stack(g, -1).reshape(-1, 3)
        self.P = self.lo + (self.idx + 0.5) * v
        self.D = np.full(len(self.P), 1e9)
        self.M = np.zeros(len(self.P), int)

    def add(self, d, m, k=0.0):
        if k > 0:
            h = np.clip(0.5 + 0.5 * (self.D - d) / k, 0, 1)
            nd = d * h + self.D * (1 - h) - k * h * (1 - h)
        else:
            nd = np.minimum(self.D, d)
        self.M = np.where(d < self.D, m, self.M)
        self.D = nd

    def carve(self, d, m=None):
        nd = np.maximum(self.D, -d)
        if m is not None:
            wall = (-d >= self.D - 0.02) & (nd <= 0) & (nd > -1.6 * self.v)
            self.M = np.where(wall, m, self.M)
        self.D = nd

    def paint(self, mask, m, depth=None):
        sel = mask & (self.D <= 0)
        if depth is not None:
            sel = sel & (self.D > -depth)
        self.M = np.where(sel, m, self.M)

    def _probe(self, P):
        i = np.floor((P - self.lo) / self.v).astype(int)
        ok = np.all((i >= 0) & (i < self.n), axis=1)
        flat = np.where(ok, (i[:, 0] * self.n[1] + i[:, 1]) * self.n[2] + i[:, 2], 0)
        return ok & (self.D[flat] <= 0)

    def front(self, x, y, z0=-20.0, z1=20.0):
        """The z where the solid starts coming from the front (-z), at (x, y)."""
        zs = np.arange(z0, z1, self.v / 4)
        inside = self._probe(np.stack([np.full_like(zs, x), np.full_like(zs, y), zs], 1))
        k = int(np.argmax(inside))
        return zs[k] if inside[k] else None

    def top(self, x, z, y0=40.0, y1=-20.0):
        ys = np.arange(y0, y1, -self.v / 4)
        inside = self._probe(np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1))
        k = int(np.argmax(inside))
        return ys[k] if inside[k] else None

    def grid(self):
        """Palette index per voxel (nx, ny, nz), shaded, and how many faces each voxel shows.

        A voxel's shade (0 = darkest of its material) is base * (shades - 1), plus smooth noise (`noise`, `fine`),
        a highlight on edges and corners (`edge`), baked ambient occlusion (`ao`: lighter on convex parts, darker in
        creases; measured as how full a (2 * aor + 1)^3 cube round the voxel is) and a soft top light (`top`: faces
        open to the sky lighter, undersides darker), all in shade steps."""
        solid = self.D <= 0
        mg = np.zeros(tuple(self.n), int)
        mg[tuple(self.idx[solid].T)] = self.M[solid]
        occ = mg > 0
        pad = np.pad(occ, 1)
        nbs = [pad[2:, 1:-1, 1:-1], pad[:-2, 1:-1, 1:-1], pad[1:-1, 2:, 1:-1], pad[1:-1, :-2, 1:-1], pad[1:-1, 1:-1, 2:], pad[1:-1, 1:-1, :-2]]
        exposed = sum((~n).astype(int) for n in nbs) * occ
        shape = tuple(self.n)
        sh0 = self.shade
        nz = noise(self.P, sh0["freq"], self.seed).reshape(shape)
        nz2 = noise(self.P, sh0["freq"] * 3.1, self.seed + 7).reshape(shape)
        # ambient occlusion: the share of a cube round each voxel that is solid (0.5 on a flat surface)
        r = int(sh0.get("aor", 2))
        n = 2 * r + 1
        cs = np.pad(np.pad(occ.astype(float), r), ((1, 0), (1, 0), (1, 0))).cumsum(0).cumsum(1).cumsum(2)
        box_sum = (cs[n:, n:, n:] - cs[:-n, n:, n:] - cs[n:, :-n, n:] - cs[n:, n:, :-n]
                   + cs[:-n, :-n, n:] + cs[:-n, n:, :-n] + cs[n:, :-n, :-n] - cs[:-n, :-n, :-n])
        fill = box_sum / float(n ** 3)
        # top light: solid below and open above = a face toward the sky
        up = np.zeros(shape)
        down = np.zeros(shape)
        o = occ.astype(float)
        for k in range(1, r + 1):
            up[:, :-k, :] += o[:, k:, :]
            down[:, k:, :] += o[:, :-k, :]
        toward_sky = (down - up) / float(r)
        out = np.zeros(shape, int)
        for mid in range(1, len(self.pal.mats)):
            sel = mg == mid
            if not sel.any():
                continue
            shades = self.pal.mats[mid]
            k = len(shades)
            if k == 1:
                out[sel] = shades[0]
                continue
            sh = dict(sh0)
            sh.update(self.pal.mshade[mid] or {})
            base = ((k - 1) * sh["base"] + nz[sel] * sh["noise"] + nz2[sel] * sh["fine"] + (exposed[sel] >= 2) * sh["edge"]
                    + (0.5 - fill[sel]) * 2 * sh.get("ao", 0.0) + toward_sky[sel] * sh.get("top", 0.0))
            i = np.clip(np.round(base), 0, k - 1).astype(int)
            out[sel] = np.array(shades)[i]
        return out, exposed

    def origin_index(self):
        """The pivot's position in cells from the grid corner (a whole number, or .5 with a half-voxel phase)."""
        return np.round(-self.lo / self.v * 2) / 2


def greedy(cg, exposed):
    """Boxes (x, y, z, sx, sy, sz, colour) in grid cells: every visible voxel in exactly one box of its colour;
    hidden voxels may join any box; leftover hidden voxels are dropped."""
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


def check(cg, exposed, boxes):
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


# ---------------------------------------------------------------------------------------------------------------
# output
# ---------------------------------------------------------------------------------------------------------------
def write_luau(path, title, pal, sculpts, extra=None):
    """A shape module for shared/SculptKit: PALETTE { r, g, b, material, tag }, GROUPS (8 characters per box:
    min corner x, y, z in cells from the grid corner, size sx, sy, sz in cells, colour as two digits; `origin` is
    the pivot's cell, `voxel` the cell size). Returns the box count."""
    lines = [
        "-- GENERATED by tools/blender/voxel/%s. Don't edit by hand: change the sculpture there and run it again." % title,
        "-- A voxel sculpture for shared/SculptKit: per group, `boxes` holds 8 characters per box (min corner x, y, z in",
        "-- cells from the grid corner, size sx, sy, sz in cells, then the palette colour as two base-90 digits), each",
        "-- character's value its position in SculptKit's ALPHA; `origin` is the pivot's cell, `voxel` the cell size,",
        "-- `pivot` the group's pivot in its parent's frame.",
        "return {",
        "\tPALETTE = {",
    ]
    for e in pal.entries[1:]:
        r, g, b, material, tag = e
        lines.append('\t\t{ %d, %d, %d, "%s"%s },' % (r, g, b, material, ', "%s"' % tag if tag else ""))
    lines.append("\t},")
    if extra:
        for k, v in extra.items():
            lines.append("\t%s = %s," % (k, v))
    lines.append("\tGROUPS = {")
    total = 0
    for S in sculpts:
        cg, exposed = S.grid()
        boxes = greedy(cg, exposed)
        check(cg, exposed, boxes)
        total += len(boxes)
        enc = []
        n = len(ALPHA)
        for b in boxes:
            assert max(b[:6]) < n and b[6] < n * n, (S.name, b)
            enc.append("".join(ALPHA[v] for v in b[:6]) + ALPHA[b[6] // n] + ALPHA[b[6] % n])
        s = "".join(enc)
        o = S.origin_index()
        lines.append("\t\t{")
        lines.append('\t\t\tname = "%s", voxel = %s, origin = Vector3.new(%g, %g, %g),' % (S.name, repr(float(S.v)), o[0], o[1], o[2]))
        lines.append("\t\t\tpivot = Vector3.new(%s, %s, %s)," % tuple(repr(round(float(c), 4)) for c in S.pivot))
        lines.append("\t\t\tparent = %s," % ('"%s"' % S.parent if S.parent else "nil"))
        lines.append("\t\t\tboxes = table.concat({")
        for i in range(0, len(s), 112):
            lines.append("\t\t\t\t[[%s]]," % s[i : i + 112])  # (112 = 14 boxes a line)
        lines.append("\t\t\t}),")
        lines.append("\t\t},")
        print("  %-10s v=%.3f voxels %6d  boxes %5d" % (S.name, S.v, int((cg > 0).sum()), len(boxes)))
    lines.append("\t},")
    lines.append("}")
    open(path, "w").write("\n".join(lines) + "\n")
    print("%s: %d boxes -> %s (%d bytes)" % (title, total, path, os.path.getsize(path)))
    return total


def voxels_of(S):
    """{(x, y, z): palette index} with keys in cells from the pivot (for previews)."""
    cg, _ = S.grid()
    nzs = np.argwhere(cg > 0)
    return {(int(i), int(j), int(k)): int(cg[i, j, k]) for i, j, k in nzs}


def corner_of(S):
    """The grid corner (cell 0's low corner) relative to the pivot, in studs: voxel key k spans
    corner + k * v .. corner + (k + 1) * v (pair with voxels_of)."""
    return S.lo.copy()
