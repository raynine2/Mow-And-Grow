"""Wheat Farm tuft, ~5 tall: 7 thin golden wheat stalks, each topped by a chunky wheat ear made of diamond kernels
paired in a chevron, with two whiskers. Bottom at z = 0, no ground tile."""
import math
import random
import bmesh
from mathutils import Matrix, Vector

PREVIEW = dict(dist=12, height=6.5, target_z=2.6)

def strip(lib, name, base, ang, w0, t0, segs, mat, start=(0.0, 0.0, 0.0), cap=False, bevel=0.0):
    """A bent blade/leaf/stalk mesh (8 tris per segment + 6, + 2 with `cap`). It starts at `base` with a w0 x t0
    cross-section and runs through `segs` = [(length, lean_deg, width, thick), ...], each segment leaning lean_deg
    from vertical toward the direction `ang` (degrees around Z, 0 = +Y) and ending with that width/thickness. The
    last segment ends in a flat tip edge of its width. Cross-sections stay perpendicular to the spine so strongly
    bent blades keep their thickness. `start` = (y, z, lean_rad) begins the strip partway up another one (e.g. a
    wheat head on its stalk); the bottom face is left open unless `cap` (it sits in the ground or inside a stalk).
    Returns (object, end point (y, z) before the Z rotation, last lean in radians)."""
    bm = bmesh.new()
    pts, angs = [(start[0], start[1])], []
    for length, lean, _, _ in segs:
        a = math.radians(lean); y, z = pts[-1]
        pts.append((y + math.sin(a) * length, z + math.cos(a) * length)); angs.append(a)
    def ring(p, a, w, t):
        ny, nz = math.cos(a) * t / 2, -math.sin(a) * t / 2
        return [bm.verts.new((x * w / 2, p[0] + s * ny, p[1] + s * nz)) for x, s in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    rings = [ring(pts[0], start[2], w0, t0)]
    for i, (_, _, w, t) in enumerate(segs[:-1]):
        rings.append(ring(pts[i + 1], (angs[i] + angs[i + 1]) / 2, w, t))
    tw = segs[-1][2]
    tip = [bm.verts.new((x * tw / 2, pts[-1][0], pts[-1][1])) for x in (-1, 1)]
    if cap:
        bm.faces.new(list(reversed(rings[0])))
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(4):
            bm.faces.new((r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i]))
    r = rings[-1]
    bm.faces.new((r[0], r[1], tip[1], tip[0])); bm.faces.new((r[2], r[3], tip[0], tip[1]))
    bm.faces.new((r[1], r[2], tip[1])); bm.faces.new((r[3], r[0], tip[0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = lib._finish(lib._from_bmesh(name, bm), mat, base, (0, 0, ang), bevel)
    return obj, pts[-1], angs[-1]

def ear(lib, name, base, ang, top, lean, mat, pairs=3):
    """A wheat ear on top of a stalk: `pairs` pairs of diamond kernels angled out in a chevron, plus one kernel on
    top (8 tris per kernel). `top` = (y, z) of the stalk tip and `lean` its angle (radians), as strip() returns.
    Returns the ear's tip (y, z) in the same frame."""
    bm = bmesh.new()
    place = Matrix.Translation((0, top[0], top[1])) @ Matrix.Rotation(-lean, 4, "X")
    def kernel(m, w, t, h):
        vs = [bm.verts.new(m @ Vector(p)) for p in ((w / 2, 0, 0), (0, t / 2, 0), (-w / 2, 0, 0), (0, -t / 2, 0), (0, 0, h / 2), (0, 0, -h / 2))]
        for k in range(4):
            bm.faces.new((vs[k], vs[(k + 1) % 4], vs[4])); bm.faces.new((vs[(k + 1) % 4], vs[k], vs[5]))
    for p in range(pairs):
        d = 0.26 + p * 0.46
        size = 1.3 - p * 0.12
        for side in (-1, 1):
            kernel(place @ Matrix.Translation((side * 0.15 * size, 0, d)) @ Matrix.Rotation(math.radians(side * 24), 4, "Y"),
                   0.34 * size, 0.36 * size, 0.62 * size)
    tip_d = 0.26 + pairs * 0.46
    kernel(place @ Matrix.Translation((0, 0, tip_d - 0.05)), 0.36, 0.38, 0.7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    lib._finish(lib._from_bmesh(name, bm), mat, base, (0, 0, ang), 0)
    return (top[0] + math.sin(lean) * (tip_d + 0.15), top[1] + math.cos(lean) * (tip_d + 0.15))

def build(lib):
    rnd = random.Random(9)
    stalk_m = lib.material("Grass", (210, 184, 98))
    head_m = lib.material("Grass", (220, 180, 70))
    stalks = [(0, 0.0, 3.3)] + [(i * 60 + rnd.uniform(-12, 12), rnd.uniform(0.6, 0.95), rnd.uniform(2.6, 3.2)) for i in range(6)]
    for i, (ang, r, h) in enumerate(stalks):
        base = lib.rotated((0, r, 0), ang)
        lean = 2 if r == 0 else rnd.uniform(6, 11)
        _, top, a = strip(lib, "stalk%d" % i, base, ang, 0.2, 0.2, [(h * 0.5, lean, 0.17, 0.17), (h * 0.5, lean + 5, 0.15, 0.15)], stalk_m)
        tip = ear(lib, "ear%d" % i, base, ang, top, a, head_m)
        # two whiskers fanning out of the tip
        for k, side in enumerate((-1, 1)):
            strip(lib, "awn%d_%d" % (i, k), base, ang + side * 16, 0.08, 0.08, [(0.8, math.degrees(a) + 8, 0.03, 0.03)], head_m,
                  start=(tip[0] - 0.1, tip[1] - 0.2, a))
