"""Swamp Vine, the zone 4 boss (Swamp Reeds), ~20 tall.

A murky purple tangle: four thick vines twist up out of a muddy swamp clump (with reeds poking out of the mud)
and braid together into a bulb-shaped head. The head wears a crest of curled dark-purple thorn-leaves, glares
forward (+Y) with two glowing green Neon eyes under heavy brows, and grins with a jagged mouth of crooked fangs.
Leaves sprout off the vines, droopy leaf ears hang off the head, two whip-like tendril arms curl out to
the sides, and strands of swamp moss hang off the head and arms.
"""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _bosskit as bk  # noqa: E402
from mathutils import Vector  # noqa: E402

PREVIEW = dict(dist=40, height=13, target_z=10, yaw=32)

HEAD = (0, 0.4, 15.4)
HR = (3.9, 3.3, 3.5)


def build(lib):
    rnd = random.Random(7)
    purple = lib.material("SmoothPlastic", (90, 70, 140))
    purple_d = lib.material("SmoothPlastic", (60, 44, 98))
    glow = lib.material("Neon", (180, 255, 70))
    dark = lib.material("SmoothPlastic", (30, 20, 36))
    fang = lib.material("SmoothPlastic", (226, 222, 190))
    mud = lib.material("Mud", (74, 62, 46))
    reed = lib.material("Grass", (80, 140, 90))
    moss = lib.material("LeafyGrass", (84, 118, 52))

    # ---- swamp clump: mud mound, reeds, a few rocks of mud ---------------------------------------------------
    bk.ellipsoid(lib, "mud", (5.6, 5.2, 1.5), (0, 0, 0), mud, segs=12, rings=3, z_cut=0)
    for i in range(5):
        a = math.radians(i * 72 + 20)
        lib.box("lump%d" % i, (2.0, 1.8, 1.2), (math.sin(a) * 4.4, math.cos(a) * 4.0, 0.5), rot=(0, 0, rnd.uniform(0, 90)),
                mat=mud, bevel=0.2)
    for i in range(9):
        a = math.radians(i * 40 + rnd.uniform(-10, 10))
        r = rnd.uniform(3.6, 5.2)
        h = rnd.uniform(2.8, 4.8)
        lib.box("reed%d" % i, (0.45, 0.3, h), (math.sin(a) * r, math.cos(a) * r, h / 2 + 0.3),
                rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), math.degrees(a)), mat=reed, taper=(0.2, 0.6))

    # ---- twisting body vines ---------------------------------------------------------------------------------
    for i in range(4):
        pts = bk.helix((0, 0.1), 0.6, HEAD[2] - 1.5, 3.4, 1.0, 0.85, i * math.pi / 2, 9)
        bk.tube(lib, "vine%d" % i, pts, [1.25 - 0.4 * k / 9 for k in range(10)], (purple, purple_d)[i % 2], verts=8)
        # a few thorns along each vine
        for k in (2, 5, 7):
            p = Vector(pts[k]); out = Vector((p.x, p.y, 0)).normalized()
            bk.cone(lib, "vthorn%d_%d" % (i, k), tuple(p + out * 0.6), tuple(p + out * 1.9 + Vector((0, 0, 0.6))), 0.32, purple_d, verts=5)
        # leaves sprouting off the vine
        for k in ((3,) if i % 2 else (5,)):
            p = Vector(pts[k]); ang = math.degrees(math.atan2(p.x, p.y))
            bk.leaf(lib, "vleaf%d_%d" % (i, k), tuple(p), ang + 25, 28, 2.8 - k * 0.15, 1.5, 0.25, (moss, purple_d)[(i + k) % 2],
                    bends=[(0.5, 30)])
    # neck block so the vines read as one body under the head
    bk.ellipsoid(lib, "neck", (2.3, 2.1, 2.6), (0, 0.2, HEAD[2] - 3.0), purple_d, segs=10, rings=5)

    # ---- tendril arms ------------------------------------------------------------------------------------------
    for side in (-1, 1):
        pts = [(side * 1.4, 0.0, 9.0), (side * 3.6, 0.6, 9.8), (side * 5.6, 1.4, 9.4), (side * 6.9, 2.2, 10.6),
               (side * 7.1, 2.8, 12.4), (side * 6.2, 3.2, 13.4), (side * 5.4, 3.0, 12.6)]
        bk.tube(lib, "arm%d" % side, pts, [0.95, 0.85, 0.72, 0.6, 0.5, 0.42, 0.34], purple, verts=8)
        bk.leaf(lib, "armleaf%d" % side, (side * 4.6, 1.0, 9.9), side * 120, 30, 2.6, 1.4, 0.25, purple_d)
        for j, (x, y, z) in enumerate(((side * 3.4, 0.6, 9.4), (side * 6.0, 1.6, 9.2))):
            lib.box("armmoss%d_%d" % (side, j), (0.4, 0.25, 2.4), (x, y, z - 1.3), rot=(0, rnd.uniform(-8, 8), 0), mat=moss,
                    taper=(0.4, 0.8))

    # ---- head --------------------------------------------------------------------------------------------------
    bk.ellipsoid(lib, "head", HR, HEAD, purple, segs=12, rings=8)
    surf = bk.ellip_surface(HEAD, HR)
    # crest of curled thorn-leaves, sweeping back
    for i, (x, lean, ln) in enumerate(((-2.4, -28, 3.0), (-1.2, -10, 3.8), (0, 0, 4.4), (1.2, 10, 3.8), (2.4, 28, 3.0))):
        base = Vector((x, HEAD[1] - 0.6, HEAD[2] + HR[2] * 0.75 - abs(x) * 0.3))
        mid = base + Vector((x * 0.2, -0.9, ln * 0.55))
        tip = mid + Vector((x * 0.25, -1.6, ln * 0.3))
        bk.tube(lib, "crest%d" % i, [tuple(base), tuple(mid)], [0.75, 0.5], purple_d, verts=6)
        bk.cone(lib, "crest_tip%d" % i, tuple(mid), tuple(tip), 0.5, purple_d, verts=6)
    # droopy leaf ears
    for side in (-1, 1):
        bk.leaf(lib, "ear%d" % side, (side * HR[0] * 0.8, HEAD[1] - 0.3, HEAD[2] + 0.8), side * 100, 20, 3.6, 2.0, 0.3, purple_d,
                bends=[(0.45, 35)])
    # hanging moss off the jaw line
    for i, x in enumerate((-3.4, -2.6, 2.7, 3.3, -1.0)):
        p, _ = surf(x, HEAD[2] - 1.6 - abs(x) * 0.15)
        ln = rnd.uniform(1.8, 3.0)
        lib.box("moss%d" % i, (0.55, 0.3, ln), (p.x, p.y - 0.8, p.z - ln / 2 + 0.2), rot=(0, rnd.uniform(-6, 6), 0), mat=moss,
                taper=(0.4, 0.8))

    # ---- face: glowing eyes in dark sockets, heavy brows, jagged grin -----------------------------------------
    for side in (-1, 1):
        x, z = side * 1.55, HEAD[2] + 0.75
        bk.eye(lib, "socket%d" % side, surf, x, z - 0.05, 1.12, dark, None, h=0.9)
        bk.eye(lib, "eye%d" % side, surf, x, z - 0.1, 0.8, glow, None, brow=28, brow_mat=purple_d, h=0.85, sink=-0.12)
    bk.mouth(lib, "mouth", surf, HEAD[2] - 1.45, 4.2, 1.9, dark, fang, top_teeth=5, bottom_teeth=3, frown=0.45)
    bk.scale_all(0.92)
