"""Jungle Titan, the zone 5 boss (Mega Jungle), ~22 tall: the biggest weed monster.

A hulking dark-green plant golem built from chunky bevelled blocks: stumpy bark legs splaying into root toes, a
broad hunched torso patched with lighter moss and wrapped in a vine, huge leafy shoulder pads (a fan of broad
jungle leaves over a mossy dome, with a few orange flowers), long gorilla arms ending in heavy bark fists, and a
squat head sunk between the shoulders. The face on the front (+Y) has a heavy brow ridge over two glowing amber
Neon eyes and a jagged mouth of wooden fangs; a crown of tall jungle leaves sprouts from the top of the head.
"""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _bosskit as bk  # noqa: E402
from mathutils import Vector  # noqa: E402

PREVIEW = dict(dist=44, height=15, target_z=11, yaw=32)


def build(lib):
    rnd = random.Random(55)
    body = lib.material("Grass", (20, 90, 40))
    leafm = lib.material("Grass", (44, 128, 46))
    moss = lib.material("LeafyGrass", (86, 150, 52))
    bark = lib.material("Wood", (96, 64, 40))
    glow = lib.material("Neon", (255, 186, 40))
    dark = lib.material("SmoothPlastic", (22, 26, 20))
    fang = lib.material("Wood", (214, 190, 140))
    flower = lib.material("SmoothPlastic", (255, 110, 30))

    # ---- legs + root toes --------------------------------------------------------------------------------------
    for side in (-1, 1):
        x = side * 2.7
        lib.box("leg%d" % side, (3.4, 3.4, 6.4), (x, 0, 3.4), rot=(0, 0, side * 4), mat=bark, bevel=0.3, taper=(0.86, 0.86))
        lib.box("knee%d" % side, (3.0, 1.0, 2.2), (x, 1.75, 4.6), mat=moss, bevel=0.2)
        for j, a in enumerate((-35, 0, 35)):
            ang = a + side * 10
            p = lib.rotated((0, 2.0, 0.55), ang)
            lib.box("toe%d_%d" % (side, j), (1.3, 2.6, 1.1), (x + p[0], p[1], p[2]), rot=(-6, 0, -ang), mat=bark, bevel=0.2,
                    taper=(0.7, 0.8))
        lib.box("heel%d" % side, (2.0, 1.8, 1.0), (x, -1.9, 0.5), mat=bark, bevel=0.2)

    # ---- torso: hips, chest, moss plates, belly, vine ------------------------------------------------------------
    lib.box("hips", (7.6, 5.0, 2.4), (0, -0.2, 6.8), mat=body, bevel=0.3)
    lib.box("torso", (8.6, 6.0, 7.4), (0, -0.4, 11.2), rot=(-8, 0, 0), mat=body, bevel=0.4, taper=(1.15, 1.08))
    lib.box("belly", (5.6, 1.2, 3.6), (0, 2.6, 9.2), rot=(-6, 0, 0), mat=moss, bevel=0.3)
    for side in (-1, 1):
        lib.box("pec%d" % side, (3.6, 1.2, 2.8), (side * 2.1, 2.6, 12.6), rot=(-10, side * -6, side * 4), mat=moss, bevel=0.3)
    lib.box("backmoss", (6.0, 1.0, 4.0), (0, -3.6, 11.5), rot=(8, 0, 0), mat=moss, bevel=0.3)
    vine = [(-4.6, 1.8, 7.2), (-2.2, 3.4, 8.4), (0.8, 3.5, 10.4), (3.4, 3.4, 12.6), (4.6, 2.2, 14.0)]
    bk.tube(lib, "vine", vine, 0.45, leafm, verts=6)
    for i in (1, 3):
        p = Vector(vine[i])
        bk.leaf(lib, "vineleaf%d" % i, tuple(p + Vector((0, 0.2, 0))), 160 + i * 10, 20, 1.8, 1.0, 0.2, leafm)

    # ---- shoulders: mossy dome + fan of jungle leaves + flowers ------------------------------------------------------
    for side in (-1, 1):
        sx = side * 5.2
        bk.ellipsoid(lib, "shoulder%d" % side, (2.6, 2.8, 2.2), (sx, -0.4, 14.6), moss, segs=10, rings=5)
        for j, (ang, tilt, ln, wd) in enumerate(((side * 60, 36, 3.8, 3.4), (side * 100, 30, 4.0, 3.6), (side * 145, 32, 4.0, 3.4),
                                                (side * 80, 56, 3.6, 3.0), (side * 125, 54, 3.6, 3.0))):
            bk.leaf(lib, "pad%d_%d" % (side, j), (sx, -0.4, 15.6), ang, tilt, ln, wd, 0.35, (leafm, body)[j % 2],
                    bends=[(0.55, 30)], roll=rnd.uniform(-8, 8))
        for j, (dx, dy) in enumerate(((0.4, 1.8), (1.6, 0.4))):
            c = Vector((sx + side * dx, -0.4 + dy, 16.4 - j * 0.6))
            for k in range(5):
                a = math.radians(k * 72)
                lib.box("petal%d_%d_%d" % (side, j, k), (0.6, 1.0, 0.25), tuple(c + Vector((math.sin(a) * 0.5, math.cos(a) * 0.5, 0))),
                        rot=(0, 0, -math.degrees(a)), mat=flower)
            lib.sphere("bud%d_%d" % (side, j), 0.3, tuple(c + Vector((0, 0, 0.12))), mat=glow, subdiv=1)

    # ---- arms: upper arm, bark forearm, big fist -----------------------------------------------------------------
    for side in (-1, 1):
        sh = Vector((side * 5.6, -0.2, 13.6))
        el = Vector((side * 6.5, 0.6, 9.4))
        wr = Vector((side * 6.4, 2.0, 5.4))
        bk.tube(lib, "upper%d" % side, [tuple(sh), tuple(el)], [1.5, 1.3], body, verts=8)
        bk.tube(lib, "fore%d" % side, [tuple(el), tuple(wr)], [1.45, 1.75], bark, verts=8)
        lib.box("elbowmoss%d" % side, (2.0, 1.8, 1.4), tuple(el + Vector((side * 0.3, -0.5, 0.2))), rot=(20, 0, side * 15), mat=moss, bevel=0.2)
        fist = wr + Vector((0, 0.3, -1.6))
        lib.box("fist%d" % side, (3.0, 3.2, 2.8), tuple(fist), rot=(0, 0, side * 8), mat=bark, bevel=0.35)
        for k in range(3):
            lib.box("knuckle%d_%d" % (side, k), (0.8, 0.9, 0.8), tuple(fist + Vector((side * (-0.9 + 0.9 * k) * 0.95, 1.6, 0.6))),
                    mat=bark, bevel=0.15)
        lib.box("fistmoss%d" % side, (2.6, 2.4, 0.6), tuple(fist + Vector((0, -0.1, 1.5))), rot=(0, 0, side * 8), mat=moss, bevel=0.15)
        # thorns along the forearm
        for k, t in enumerate((0.3, 0.65)):
            p = el + (wr - el) * t
            bk.cone(lib, "athorn%d_%d" % (side, k), tuple(p + Vector((side * 1.2, 0, 0))), tuple(p + Vector((side * 2.4, -0.3, 0.7))), 0.38, fang, verts=5)

    # ---- head ---------------------------------------------------------------------------------------------------
    hz = 17.0
    lib.box("head", (6.0, 5.0, 4.8), (0, 0.9, hz), rot=(-4, 0, 0), mat=body, bevel=0.45, taper=(0.9, 0.9))
    lib.box("jaw", (5.8, 3.6, 1.8), (0, 1.5, hz - 2.3), rot=(6, 0, 0), mat=body, bevel=0.35)
    lib.box("brow", (6.4, 1.8, 1.3), (0, 3.4, hz + 1.5), rot=(-14, 0, 0), mat=moss, bevel=0.3)
    front = 3.45
    surf = bk.flat_surface(front, lean=0)
    for side in (-1, 1):
        lib.box("socket%d" % side, (2.1, 0.5, 1.35), (side * 1.5, front - 0.05, hz + 0.3), rot=(0, side * -12, 0), mat=dark, bevel=0.15)
        lib.box("eye%d" % side, (1.6, 0.5, 0.8), (side * 1.5, front + 0.08, hz + 0.22), rot=(0, side * -16, 0), mat=glow, bevel=0.14)
        # angled brow plate over each eye: inner end lower
        lib.box("browplate%d" % side, (2.9, 1.2, 0.85), (side * 1.55, front + 0.12, hz + 1.12), rot=(-10, side * -20, 0), mat=body, bevel=0.2)
    bk.mouth(lib, "mouth", bk.flat_surface(front + 0.1), hz - 1.75, 4.6, 1.9, dark, fang, top_teeth=5, bottom_teeth=2, frown=0.15)
    # leafy crown sprouting from the top of the head
    crown = ((0, 180, 68, 6.0, 3.0), (-1.2, 215, 60, 5.6, 2.8), (1.2, 145, 60, 5.6, 2.8), (-1.6, 260, 50, 4.8, 2.6),
             (1.6, 100, 50, 4.8, 2.6), (-0.6, 300, 58, 4.2, 2.2), (0.6, 60, 58, 4.2, 2.2))
    for i, (x, ang, tilt, ln, wd) in enumerate(crown):
        bk.leaf(lib, "crown%d" % i, (x, 0.2, hz + 2.1), ang, tilt, ln, wd, 0.38, (leafm, moss, body)[i % 3],
                bends=[(0.5, 38)], roll=rnd.uniform(-10, 10))
    bk.scale_all(0.94)
