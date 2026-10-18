"""Lawn grass tuft for one 6x6 Backyard Lawn tile, ~2.5 tall: a fan of chunky bent blades leaning out from the
middle in two greens, plus a ring of short blades. Built from cheap custom blade meshes (~16 tris each) so hundreds
of tufts stay light. Bottom at z = 0, no ground tile."""
import math
import random
import bmesh

PREVIEW = dict(dist=8, height=4.5, target_z=1.1)

def strip(lib, name, base, ang, w0, t0, segs, mat, bevel=0.0):
    """A bent blade/leaf/stalk mesh (8 tris per segment + 8). It starts at `base` on the ground with a w0 x t0
    cross-section and runs through `segs` = [(length, lean_deg, width, thick), ...], each segment leaning lean_deg
    from vertical toward the direction `ang` (degrees around Z, 0 = +Y) and ending with that width/thickness. The
    last segment ends in a flat tip edge of its width. Cross-sections stay perpendicular to the spine so strongly
    bent blades keep their thickness."""
    bm = bmesh.new()
    pts, angs = [(0.0, 0.0)], []
    for length, lean, _, _ in segs:
        a = math.radians(lean); y, z = pts[-1]
        pts.append((y + math.sin(a) * length, z + math.cos(a) * length)); angs.append(a)
    def ring(p, a, w, t):
        ny, nz = math.cos(a) * t / 2, -math.sin(a) * t / 2
        return [bm.verts.new((x * w / 2, p[0] + s * ny, p[1] + s * nz)) for x, s in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    rings = [ring(pts[0], 0.0, w0, t0)]
    for i, (_, _, w, t) in enumerate(segs[:-1]):
        rings.append(ring(pts[i + 1], (angs[i] + angs[i + 1]) / 2, w, t))
    tw = segs[-1][2]
    tip = [bm.verts.new((x * tw / 2, pts[-1][0], pts[-1][1])) for x in (-1, 1)]
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
    rnd = random.Random(21)
    g1 = lib.material("Grass", (78, 150, 44))
    g2 = lib.material("Grass", (104, 176, 56))
    # tall fan: 8 chunky blades, alternating greens, leaning out from the middle
    n = 8
    for i in range(n):
        ang = i * 360 / n + rnd.uniform(-14, 14)
        base = lib.rotated((rnd.uniform(-0.15, 0.15), rnd.uniform(0.3, 0.55), 0), ang)
        L = rnd.uniform(1.35, 1.55)
        w = rnd.uniform(0.72, 0.86)
        strip(lib, "blade%d" % i, base, ang, w, 0.3, [(L, rnd.uniform(10, 18), w * 0.9, 0.28),
                                                     (L, rnd.uniform(38, 50), w * 0.18, 0.12)], (g1, g2)[i % 2])
    # two nearly upright centre blades
    for i, ang in enumerate((40, 220)):
        strip(lib, "centre%d" % i, lib.rotated((0, 0.12, 0), ang), ang, 0.74, 0.3,
              [(1.4, 3, 0.68, 0.28), (1.3, 16, 0.14, 0.12)], (g2, g1)[i])
    # short blades filling the gaps
    for i in range(6):
        ang = i * 60 + 22 + rnd.uniform(-10, 10)
        base = lib.rotated((0, rnd.uniform(0.75, 1.0), 0), ang)
        strip(lib, "short%d" % i, base, ang, 0.62, 0.26, [(0.75, rnd.uniform(20, 28), 0.56, 0.24),
                                                         (0.7, rnd.uniform(48, 60), 0.12, 0.1)], (g2, g1)[i % 2])
