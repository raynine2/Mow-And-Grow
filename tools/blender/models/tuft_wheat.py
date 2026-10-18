"""Wheat clump (Wheat Farm), ~6.5 tall, footprint radius ~2.3: a bundle of golden wheat stalks.

Seven thick golden stalks fan gently out of the ground, each carrying a chunky grain ear (four crossed pairs of fat
diamond kernels round a darker core, a top kernel and two whiskers), with a few long green-gold leaves curling out at the
base. Bottom at z = 0, centred on x = y = 0, no ground tile. `layout()` is shared with tuft_wheat_cut.
"""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import _grasskit as gk  # noqa: E402
import _bosskit as bk  # noqa: E402

PREVIEW = dict(dist=13, height=6.2, target_z=3.1, yaw=30)

STALK, HEAD1, HEAD2, LEAF = (214, 178, 84), (246, 206, 92), (214, 158, 52), (146, 168, 64)


def layout():
    rnd = random.Random(9)
    out = [dict(kind="stalk", ang=rnd.uniform(0, 360), r=0.0, h=4.1, lean=2)]
    for ang, r in gk.ring_positions(rnd, 6, 0.5, 0.7, phase=15, jitter=12):
        out.append(dict(kind="stalk", ang=ang, r=r, h=rnd.uniform(3.3, 3.8), lean=rnd.uniform(11, 16)))
    for ang, r in gk.ring_positions(rnd, 4, 0.6, 0.8, phase=40, jitter=20):
        out.append(dict(kind="leaf", ang=ang, r=r, lean=rnd.uniform(18, 26), s=rnd.uniform(0.9, 1.1)))
    return out


def kernel(bm, m, w, t, h):
    """A fat diamond grain (octahedron, 8 tris) placed by matrix m."""
    vs = [bm.verts.new(m @ Vector(p)) for p in ((w / 2, 0, 0), (0, t / 2, 0), (-w / 2, 0, 0), (0, -t / 2, 0), (0, 0, h / 2), (0, 0, -h / 2))]
    for k in range(4):
        bm.faces.new((vs[k], vs[(k + 1) % 4], vs[4])); bm.faces.new((vs[(k + 1) % 4], vs[k], vs[5]))


def ear(lib, name, tip, direction, spin, mats, s=1.0):
    """A chunky grain ear standing on a stalk tip, along `direction`: 3 tiers of kernel pairs, each tier turned 90
    degrees (so it is full from every side), a top kernel, a darker gold core and two whiskers."""
    q = Vector(direction).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    place = Matrix.Translation(tip) @ q @ Matrix.Rotation(math.radians(spin), 4, "Z")
    bms = [bmesh.new(), bmesh.new()]
    tiers = 4
    for p in range(tiers):
        d = (0.28 + p * 0.34) * s
        size = (1.12 - p * 0.07) * s
        turn = Matrix.Rotation(math.radians(90 * p), 4, "Z")
        for side in (-1, 1):
            kernel(bms[0], place @ turn @ Matrix.Translation((side * 0.19 * size, 0, d)) @ Matrix.Rotation(math.radians(side * 18), 4, "Y"),
                   0.5 * size, 0.5 * size, 0.7 * size)
    top = 0.28 + tiers * 0.34
    kernel(bms[0], place @ Matrix.Translation((0, 0, top * s - 0.06)), 0.46 * s, 0.46 * s, 0.74 * s)
    # a darker solid core between the kernels so the ear reads as one chunky head
    bm = bms[1]
    lo = [bm.verts.new(place @ Vector((x * 0.2 * s, y * 0.2 * s, 0.02))) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [bm.verts.new(place @ Vector((x * 0.14 * s, y * 0.14 * s, top * s))) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(hi)
    for k in range(4):
        bm.faces.new((lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k]))
    for i, bm in enumerate(bms):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        lib._from_bmesh("%s_%d" % (name, i), bm).data.materials.append(mats[i])
    # two whiskers fanning out of the top
    for side in (-1, 1):
        a = place @ Vector((side * 0.08, 0, top * s + 0.1))
        b = place @ Vector((side * 0.42, 0.12 * side, top * s + 1.05))
        bk.cone(lib, "%s_awn%d" % (name, side), a, b, 0.09, mats[1], verts=3)


def build(lib):
    stalk = lib.material("Grass", STALK)
    heads = [lib.material("Fabric", HEAD1), lib.material("Fabric", HEAD2)]
    leaf = lib.material("Grass", LEAF)
    rnd = random.Random(3)
    for i, b in enumerate(layout()):
        base = lib.rotated((0, b["r"], 0.0), b["ang"])
        if b["kind"] == "leaf":
            s = b["s"]
            gk.blade(lib, "leaf%d" % i, base, b["ang"], 0.5, 0.16,
                     [(1.0 * s, b["lean"], 0.62, 0.16, 0), (1.0 * s, b["lean"] + 22, 0.58, 0.14, 0),
                      (0.9 * s, b["lean"] + 52, 0.12, 0.08, 0)], [leaf], sides=4, twist=30, tip="edge")
            continue
        h, lean = b["h"], b["lean"]
        info = gk.blade(lib, "stalk%d" % i, base, b["ang"], 0.26, 0.26,
                        [(h * 0.55, lean, 0.24, 0.24, 0), (h * 0.45, lean + 4, 0.2, 0.2, 0)], [stalk], sides=4,
                        twist=45, tip="open")
        ear(lib, "ear%d" % i, info["tip"] - info["dir"] * 0.1, info["dir"], rnd.uniform(0, 90), heads, 1.0)
