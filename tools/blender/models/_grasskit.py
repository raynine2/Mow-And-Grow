"""Private helpers for the grass clumps (tuft_*) and their cut stubble (tuft_*_cut).

build.py skips files that start with "_", so this is never built as a model. Load it from a tuft model with:

    import os, sys; sys.path.insert(0, os.path.dirname(__file__)); import _grasskit as gk

A clump is made of chunky bent blades: thick tapered slabs (a box or a hexagon with a raised mid-rib in cross-section)
that run up a bent spine, can twist a little, and change material per segment (dark base -> green body -> light tip).
Each tuft file describes its blades as plain dicts (`layout()`), so its _cut twin can put a cut stub at the same
places: a short sheared prism cut flat at a height with a light "fresh cut" cap on top, plus clippings on the ground.
"""
import math
import bmesh
from mathutils import Matrix, Vector


def _section(sides, w, t, fold=0.0):
    """Cross-section points (u across the blade, v through its thickness; -v is the blade's upper/inner face).
    fold lifts the hexagon's edges by fold * w toward -v, folding the blade into a V along its mid-rib."""
    if sides == 6:   # hexagon: thick edges and a raised mid-rib, so the blade shades in two facets
        f = fold * w
        return [(-w / 2, -t * 0.28 - f), (0, -t / 2), (w / 2, -t * 0.28 - f), (w / 2, t * 0.28 - f), (0, t / 2),
                (-w / 2, t * 0.28 - f)]
    if sides == 8:   # round-ish stalk
        return [(math.cos(2 * math.pi * k / 8) * w / 2, math.sin(2 * math.pi * k / 8) * t / 2) for k in range(8)]
    return [(-w / 2, -t / 2), (w / 2, -t / 2), (w / 2, t / 2), (-w / 2, t / 2)]


def blade(lib, name, base, ang, w0, t0, segs, mats, sides=4, twist=0.0, tip="point", cap=False, start=None, fold=0.0):
    """A bent blade / leaf / stalk from `base` (x, y, z), heading `ang` degrees around Z (0 = +Y, lib.rotated's sense).

    segs = [(length, lean_deg, width, thick, mat_index), ...]: each segment leans lean_deg from vertical toward the
    heading and ends with that cross-section; mats[mat_index] colours it (runs of one material become one object).
    tip = "point" (the last segment closes to a point), "edge" (a flat edge of the last width) or "open"/"flat"
    (open end / flat capped end, e.g. a stalk that carries a head). `twist` = total degrees the blade twists along
    its length. `start` = (y, z, lean_deg) starts the spine somewhere else in the blade's own frame. `fold` (sides=6)
    folds the blade into a V along its mid-rib (edges lifted by fold * width), so wide leaves still show from the side.
    Returns a dict with the world `tip` point, the world `dir` (unit vector) of the last segment and `lean`."""
    y, z = (start[0], start[1]) if start else (0.0, 0.0)
    a0 = math.radians(start[2]) if start else 0.0
    pts, leans = [(y, z)], []
    for seg in segs:
        a = math.radians(seg[1])
        y, z = pts[-1]
        pts.append((y + math.sin(a) * seg[0], z + math.cos(a) * seg[0]))
        leans.append(a)
    n = len(segs)

    def frame(i):
        a = a0 if i == 0 else (leans[i - 1] if i == n else (leans[i - 1] + leans[i]) / 2)
        tw = math.radians(twist) * i / n
        X = Vector((math.cos(tw), 0, 0)) + Vector((0, math.cos(a), -math.sin(a))) * math.sin(tw)
        N = Vector((0, math.cos(a), -math.sin(a))) * math.cos(tw) - Vector((1, 0, 0)) * math.sin(tw)
        return Vector((0, pts[i][0], pts[i][1])), X, N

    sizes = [(w0, t0)] + [(s[2], s[3]) for s in segs]
    rings = []
    for i in range(n + 1):
        p, X, N = frame(i)
        if i == n and tip == "point":
            rings.append([p])
        elif i == n and tip == "edge":
            rings.append([p - X * sizes[i][0] / 2, p + X * sizes[i][0] / 2])
        else:
            rings.append([p + X * u + N * v for u, v in _section(sides, *sizes[i], fold=fold)])
    # group consecutive segments by material
    groups, g0 = [], 0
    for i in range(1, n + 1):
        if i == n or segs[i][4] != segs[g0][4]:
            groups.append((g0, i, segs[g0][4])); g0 = i
    rot = Matrix.Rotation(math.radians(ang), 4, "Z")
    for gi, (i0, i1, mi) in enumerate(groups):
        bm = bmesh.new()
        vr = [[bm.verts.new(c) for c in rings[i]] for i in range(i0, i1 + 1)]
        if cap and i0 == 0:
            bm.faces.new(list(reversed(vr[0])))
        for r0, r1 in zip(vr, vr[1:]):
            m = len(r0)
            if len(r1) == 1:
                for k in range(m):
                    bm.faces.new((r0[k], r0[(k + 1) % m], r1[0]))
            elif len(r1) == 2:      # flat edge tip: each section corner joins the tip end on its side
                side = [r1[1] if u >= 0 else r1[0] for u, _ in _section(sides, 1, 1)]
                for k in range(m):
                    ta, tb = side[k], side[(k + 1) % m]
                    bm.faces.new((r0[k], r0[(k + 1) % m], tb) if ta is tb else (r0[k], r0[(k + 1) % m], tb, ta))
            else:
                for k in range(m):
                    bm.faces.new((r0[k], r0[(k + 1) % m], r1[(k + 1) % m], r1[k]))
        if i1 == n and tip == "flat":
            bm.faces.new(vr[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = lib._from_bmesh("%s_%d" % (name, gi), bm)
        obj.data.materials.append(mats[mi])
        obj.matrix_basis = Matrix.Translation(base) @ rot
    tipw = rot @ Vector((0, pts[-1][0], pts[-1][1])) + Vector(base)
    d = rot @ Vector((0, math.sin(leans[-1]), math.cos(leans[-1])))
    return dict(tip=tipw, dir=d, lean=math.degrees(leans[-1]))


def oriented(obj, loc, direction, spin=0.0):
    """Point an object's local +Z along `direction` and move it to `loc` (spin = degrees around its own Z)."""
    q = Vector(direction).normalized().to_track_quat("Z", "Y")
    obj.matrix_basis = Matrix.Translation(loc) @ q.to_matrix().to_4x4() @ Matrix.Rotation(math.radians(spin), 4, "Z") @ obj.matrix_basis
    return obj


def stub(lib, name, base, ang, lean, w, t, h, mat, cap_mat, sides=4, taper=0.9, cap_h=0.07, slant=0.0, rim=True):
    """A cut-off blade/stem: the cross-section (w x t, `sides` 4 / 6 / 8) at the ground, sheared `lean` degrees toward
    heading `ang` and cut flat at height h (tilted `slant` degrees, for a diagonal cut), with a thin cap slab in
    `cap_mat` (the light, fresh-cut face; rim=False makes it just the flat top face, cheaper). Open at the bottom
    (it sits in the ground)."""
    sec = _section(sides, w, t)
    off = math.tan(math.radians(lean)) * h
    sl = math.tan(math.radians(slant))
    bm = bmesh.new()
    lo = [bm.verts.new((u, v, -0.05)) for u, v in sec]
    hi = [bm.verts.new((u * taper, v * taper + off, h + v * taper * sl)) for u, v in sec]
    m = len(sec)
    for k in range(m):
        bm.faces.new((lo[k], lo[(k + 1) % m], hi[(k + 1) % m], hi[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = lib._from_bmesh(name, bm); o.data.materials.append(mat)
    rot = Matrix.Rotation(math.radians(ang), 4, "Z")
    o.matrix_basis = Matrix.Translation(base) @ rot
    # cap slab
    bm = bmesh.new()
    lo = [bm.verts.new((u * taper, v * taper + off, h + v * taper * sl + (-0.01 if rim else 0.005))) for u, v in sec]
    hi = [bm.verts.new((u * taper * 0.97, v * taper * 0.97 + off, h + v * taper * sl + cap_h)) for u, v in sec]
    if rim:
        bm.faces.new(hi)
        for k in range(m):
            bm.faces.new((lo[k], lo[(k + 1) % m], hi[(k + 1) % m], hi[k]))
    else:
        bm.faces.new(lo)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if not rim:     # a lone face: make sure it faces up
        for f in bm.faces:
            if f.normal.z < 0:
                f.normal_flip()
    c = lib._from_bmesh(name + "_cap", bm); c.data.materials.append(cap_mat)
    c.matrix_basis = Matrix.Translation(base) @ rot
    return o


def clipping(lib, name, loc, ang, length, w, mat, curl=18, t=0.1, tip="edge"):
    """A cut piece of blade lying on the ground at loc (x, y), pointing at heading `ang`, its tip curling up a little
    (tip="edge": the blade's pointed end; "flat": a piece cut at both ends). ~16 tris."""
    return blade(lib, name, (loc[0], loc[1], t / 2), ang, w, t,
                 [(length * 0.55, 90, w * 0.95, t, 0), (length * 0.45, 90 - curl, w * 0.45 if tip == "edge" else w * 0.8, t * 0.8, 0)],
                 [mat], sides=4, tip=tip, cap=True, start=(-length / 2, 0.0, 90))


def ring_positions(rnd, n, r0, r1, phase=0.0, jitter=12.0):
    """n (heading, radius) pairs spread evenly around a ring with a little randomness."""
    return [(phase + i * 360.0 / n + rnd.uniform(-jitter, jitter), rnd.uniform(r0, r1)) for i in range(n)]


def capsule(lib, name, r, length, mat, verts=8, end=0.55, round_len=0.25):
    """A fat rounded rod along local Z centred on the origin (a cattail head): flat ends of radius r*end bevelled
    out to the full radius over round_len. 6*verts - 4 tris. Place it with oriented()."""
    bm = bmesh.new()
    zs = [(-length / 2, r * end), (-length / 2 + round_len, r), (length / 2 - round_len, r), (length / 2, r * end)]
    rings = [[bm.verts.new((math.cos(2 * math.pi * (k + 0.5) / verts) * rr, math.sin(2 * math.pi * (k + 0.5) / verts) * rr, z))
              for k in range(verts)] for z, rr in zs]
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    for a, b in zip(rings, rings[1:]):
        for k in range(verts):
            bm.faces.new((a[k], a[(k + 1) % verts], b[(k + 1) % verts], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = lib._from_bmesh(name, bm); o.data.materials.append(mat)
    return o
