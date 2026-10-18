"""Golf Course grass tuft, ~1.5 tall: short, neat, bright fairway grass. More and narrower blades than the lawn
tuft, mostly upright with a gentle outward curl, in two bright greens. Bottom at z = 0, no ground tile."""
import math
import random
import bmesh

PREVIEW = dict(dist=6, height=3.2, target_z=0.6)

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
    rnd = random.Random(5)
    g1 = lib.material("Grass", (96, 186, 58))
    g2 = lib.material("Grass", (122, 206, 70))
    # outer ring: 10 blades curling outward
    n = 10
    for i in range(n):
        ang = i * 360 / n + rnd.uniform(-8, 8)
        base = lib.rotated((0, rnd.uniform(0.55, 0.75), 0), ang)
        L = rnd.uniform(0.62, 0.72)
        strip(lib, "outer%d" % i, base, ang, 0.46, 0.22, [(L, rnd.uniform(12, 18), 0.4, 0.2),
                                                         (L * 0.9, rnd.uniform(34, 42), 0.1, 0.09)], (g1, g2)[i % 2])
    # inner ring: 7 taller, more upright blades
    n = 7
    for i in range(n):
        ang = i * 360 / n + 25 + rnd.uniform(-8, 8)
        base = lib.rotated((0, rnd.uniform(0.15, 0.3), 0), ang)
        L = rnd.uniform(0.74, 0.82)
        strip(lib, "inner%d" % i, base, ang, 0.46, 0.22, [(L, rnd.uniform(4, 9), 0.4, 0.2),
                                                         (L * 0.95, rnd.uniform(16, 24), 0.1, 0.09)], (g2, g1)[i % 2])
