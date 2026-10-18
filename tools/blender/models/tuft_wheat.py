"""Wheat Farm tuft, ~5 tall: 7 golden wheat stalks, each with a chunky tapered wheat head (bevelled block plus
a few awn spikes), and a couple of drooping leaves at the base. Bottom at z = 0, no ground tile."""
import math
import random
import bmesh

PREVIEW = dict(dist=12, height=6.5, target_z=2.6)

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
    rnd = random.Random(9)
    stalk_m = lib.material("Grass", (206, 178, 92))
    head_m = lib.material("Grass", (220, 180, 70))
    leaf_m = lib.material("Grass", (190, 168, 84))
    stalks = [(0, 0.0, 3.6)] + [(i * 60 + rnd.uniform(-12, 12), rnd.uniform(0.55, 0.85), rnd.uniform(2.9, 3.5)) for i in range(6)]
    for i, (ang, r, h) in enumerate(stalks):
        base = lib.rotated((0, r, 0), ang)
        lean = 2 if r == 0 else rnd.uniform(6, 11)
        _, top, a = strip(lib, "stalk%d" % i, base, ang, 0.24, 0.24, [(h * 0.5, lean, 0.22, 0.22), (h * 0.5, lean + 5, 0.2, 0.2)], stalk_m)
        # head: a chunky tapered block continuing the stalk's lean
        hl = rnd.uniform(1.45, 1.7)
        dy, dz = math.sin(a), math.cos(a)
        c = lib.rotated((0, top[0] + dy * (hl / 2 - 0.15), top[1] + dz * (hl / 2 - 0.15)), ang)
        lib.box("head%d" % i, (0.66, 0.6, hl), (base[0] + c[0], base[1] + c[1], c[2]), rot=(-math.degrees(a), 0, ang),
                mat=head_m, bevel=0.12, taper=(0.55, 0.6))
        # three short awns poking out of the top
        tip = (top[0] + dy * (hl - 0.2), top[1] + dz * (hl - 0.2))
        for k, ox in enumerate((-0.14, 0.0, 0.14)):
            aw = lib.rotated((ox, tip[0] + dy * 0.3, tip[1] + dz * 0.3), ang)
            lib.box("awn%d_%d" % (i, k), (0.08, 0.08, 0.7), (base[0] + aw[0], base[1] + aw[1], aw[2]),
                    rot=(-math.degrees(a), ox * 90, ang), mat=head_m)
    # drooping leaves at the base
    for i, ang in enumerate((30, 150, 270)):
        strip(lib, "leaf%d" % i, lib.rotated((0, 0.3, 0), ang), ang, 0.4, 0.14,
              [(0.9, 25, 0.36, 0.12), (0.9, 62, 0.08, 0.06)], leaf_m)
