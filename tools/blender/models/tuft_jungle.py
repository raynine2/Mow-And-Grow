"""Mega Jungle tuft, ~6 tall: a big tropical bush of broad leaves. Six long, wide, flat leaves arch out and droop
from the middle (short stalk, wide blade, pointed tip) in deep greens, over a lower ring of four splayed leaves
and around two young upright leaves in the centre. Bottom at z = 0, no ground tile."""
import math
import random
import bmesh

PREVIEW = dict(dist=15, height=8.5, target_z=2.6)

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

def build(lib):
    rnd = random.Random(17)
    g1 = lib.material("Grass", (30, 96, 38))
    g2 = lib.material("Grass", (42, 116, 44))
    g3 = lib.material("Grass", (24, 80, 32))
    mats = (g1, g2, g3)
    # six broad arching leaves: a short stalk, then a long wide blade that bends over and narrows to a point
    n = 6
    for i in range(n):
        ang = i * 360 / n + rnd.uniform(-12, 12)
        base = lib.rotated((0, rnd.uniform(0.2, 0.4), 0), ang)
        s = rnd.uniform(0.92, 1.08)
        lean = rnd.uniform(6, 14)
        strip(lib, "leaf%d" % i, base, ang, 0.4, 0.3,
              [(1.0 * s, lean, 0.5, 0.28),                 # stalk
               (1.9 * s, lean + 10, 2.0 * s, 0.26),        # blade widens
               (1.9 * s, lean + 26, 2.5 * s, 0.24),        # widest
               (1.5 * s, lean + 50, 1.7 * s, 0.22),        # arching over
               (1.2 * s, lean + 78, 0.14, 0.1)],           # drooping point
              mats[i % 3])
    # lower ring: four shorter leaves splayed out near the ground so the plant reads as a full bush
    for i in range(4):
        ang = i * 90 + 30 + rnd.uniform(-10, 10)
        base = lib.rotated((0, 0.45, 0), ang)
        strip(lib, "low%d" % i, base, ang, 0.36, 0.26,
              [(0.6, 30, 0.45, 0.24), (1.3, 45, 1.7, 0.22), (1.2, 62, 1.6, 0.2), (1.0, 84, 0.12, 0.1)], mats[(i + 1) % 3])
    # two young leaves in the middle: upright, narrower
    for i, ang in enumerate((rnd.uniform(0, 360), rnd.uniform(0, 360))):
        strip(lib, "young%d" % i, lib.rotated((0, 0.1, 0), ang), ang, 0.3, 0.28,
              [(2.4, 3, 0.4, 0.26), (1.9, 8 + i * 8, 1.4, 0.22), (1.6, 20 + i * 10, 0.1, 0.1)], g2)
