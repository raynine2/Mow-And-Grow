"""Swamp Reeds tuft, ~6.5 tall: a clump of long, thin, dark green reed blades that bend outward near the top,
with 4 brown cattail heads on straight stems poking out above them. Bottom at z = 0, no ground tile."""
import math
import random
import bmesh

PREVIEW = dict(dist=14, height=7.5, target_z=3.2)

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
    rnd = random.Random(13)
    g1 = lib.material("Grass", (46, 98, 40))
    g2 = lib.material("Grass", (62, 118, 46))
    brown = lib.material("Fabric", (112, 68, 38))
    # reed blades: three segments, almost straight then bending out at the top
    n = 9
    for i in range(n):
        ang = i * 360 / n + rnd.uniform(-15, 15)
        base = lib.rotated((0, rnd.uniform(0.2, 0.6), 0), ang)
        h = rnd.uniform(4.6, 6.0)
        strip(lib, "reed%d" % i, base, ang, 0.42, 0.2,
              [(h * 0.45, rnd.uniform(3, 7), 0.4, 0.2), (h * 0.35, rnd.uniform(12, 18), 0.32, 0.17),
               (h * 0.25, rnd.uniform(30, 42), 0.06, 0.06)], (g1, g2)[i % 2])
    # cattails: straight stem, fat brown velvet head, thin spike on top
    for i, (ang, r, h) in enumerate(((20, 0.3, 4.9), (140, 0.45, 4.4), (250, 0.35, 5.1), (320, 0.6, 4.0))):
        base = lib.rotated((0, r, 0), ang)
        lean = rnd.uniform(3, 7)
        _, top, a = strip(lib, "stem%d" % i, base, ang, 0.16, 0.16, [(h, lean, 0.14, 0.14)], g2)
        dy, dz = math.sin(a), math.cos(a)
        hl = 1.35
        c = lib.rotated((0, top[0] + dy * hl / 2, top[1] + dz * hl / 2), ang)
        lib.cyl("cattail%d" % i, 0.3, hl, (base[0] + c[0], base[1] + c[1], c[2]), rot=(-math.degrees(a), 0, ang),
                mat=brown, verts=8)
        s = lib.rotated((0, top[0] + dy * (hl + 0.35), top[1] + dz * (hl + 0.35)), ang)
        lib.box("spike%d" % i, (0.08, 0.08, 0.7), (base[0] + s[0], base[1] + s[1], s[2]), rot=(-math.degrees(a), 0, ang), mat=g2)
