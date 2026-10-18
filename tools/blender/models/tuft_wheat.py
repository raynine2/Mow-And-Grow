"""Wheat Farm tuft, ~5 tall: 7 thin golden wheat stalks, each topped by a chunky wheat ear (alternating fat and
thin kernel rings, so the silhouette is bumpy) with two whiskers, and two drooping leaves at the base.
Bottom at z = 0, no ground tile."""
import math
import random
import bmesh

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

def build(lib):
    rnd = random.Random(9)
    stalk_m = lib.material("Grass", (210, 184, 98))
    head_m = lib.material("Grass", (220, 180, 70))
    leaf_m = lib.material("Grass", (192, 170, 86))
    stalks = [(0, 0.0, 3.3)] + [(i * 60 + rnd.uniform(-12, 12), rnd.uniform(0.55, 0.85), rnd.uniform(2.6, 3.2)) for i in range(6)]
    for i, (ang, r, h) in enumerate(stalks):
        base = lib.rotated((0, r, 0), ang)
        lean = 2 if r == 0 else rnd.uniform(6, 11)
        _, top, a = strip(lib, "stalk%d" % i, base, ang, 0.2, 0.2, [(h * 0.5, lean, 0.18, 0.18), (h * 0.5, lean + 5, 0.16, 0.16)], stalk_m)
        # the ear: alternating fat and thin rings give the bumpy kernel silhouette of a wheat head
        hl = rnd.uniform(0.95, 1.05)
        la = math.degrees(a) + 3
        ear = [(0.12 * hl, la, 0.5, 0.44), (0.3 * hl, la, 0.68, 0.6), (0.12 * hl, la, 0.46, 0.4), (0.3 * hl, la, 0.64, 0.56),
               (0.12 * hl, la, 0.42, 0.36), (0.28 * hl, la, 0.56, 0.48), (0.3 * hl, la + 4, 0.14, 0.12)]
        _, tip, ta = strip(lib, "ear%d" % i, base, ang, 0.2, 0.2, ear, head_m, start=(top[0], top[1], a))
        # two awns (whiskers) fanning out of the tip
        for k, side in enumerate((-1, 1)):
            strip(lib, "awn%d_%d" % (i, k), base, ang + side * 14, 0.08, 0.08, [(0.75, math.degrees(ta) + 6, 0.03, 0.03)], head_m,
                  start=(tip[0] - 0.08, tip[1] - 0.12, ta))
    # drooping leaves at the base
    for i, ang in enumerate((30, 210)):
        strip(lib, "leaf%d" % i, lib.rotated((0, 0.3, 0), ang), ang, 0.36, 0.12,
              [(0.9, 25, 0.34, 0.12), (0.9, 62, 0.08, 0.06)], leaf_m)
