"""Venus Flytrap, the zone 3 boss (Wheat Farm), ~18 tall.

A giant carnivorous plant: two big red jaws (domes hinged at the back) gape open toward the front (+Y), pink
inside, rimmed with long white teeth, with a dark throat and a lolling pink tongue. Two angry eyes on green
stalks stick up from the top jaw, glaring forward under slanted brows. A thick curved green stem rises from a
rosette of broad leaves, with two little closed traps snapping on short stalks at the base.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _bosskit as bk  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

PREVIEW = dict(dist=36, height=13, target_z=9, yaw=30)

HINGE = Vector((0, -2.9, 10.6))


def jaw(lib, name, rx, ry, rz, up, open_deg, hinge, red, pink, white, teeth=9, tooth_len=1.4, tooth_r=0.36, pre=None):
    """One jaw: a dome hinged at `hinge`, reaching toward +Y; `up` = +1 for the top jaw, -1 for the bottom one.
    Returns the jaw's transform (to place more things in its frame)."""
    objs = []
    cy = ry * 0.85
    d = bk.ellipsoid(lib, name, (rx, ry, rz), (0, cy, 0), red, segs=14, rings=4, z_cut=0)
    if up < 0:
        bk._xform(d, (0, 0, 0), (0, 180, 0))
    objs.append(d)
    inner = lib.cyl(name + "_in", 1.0, 0.2, (0, cy, -up * 0.08), mat=pink, verts=14)
    inner.scale = (rx * 0.9, ry * 0.9, 1)
    objs.append(inner)
    # teeth around the front and sides of the rim, pointing at the other jaw and a little outward
    for i in range(teeth):
        t = math.radians(-115 + 230 * i / (teeth - 1)) + (math.radians(230 / (teeth - 1)) / 2 if up < 0 else 0)
        if abs(math.degrees(t)) > 118:
            continue
        p = Vector((rx * 0.9 * math.sin(t), cy + ry * 0.9 * math.cos(t), -up * 0.1))
        outward = Vector((math.sin(t), math.cos(t), 0)) * 0.35
        tip = p + Vector((0, 0, -up * tooth_len)) + outward * tooth_len
        objs.append(bk.cone(lib, "%s_tooth%d" % (name, i), tuple(p), tuple(tip), tooth_r, white, verts=5))
    m = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(open_deg), 4, "X")
    if pre is not None:
        m = pre @ m
    for o in objs:
        o.matrix_basis = m @ o.matrix_basis
    return m


def build(lib):
    red = lib.material("SmoothPlastic", (200, 40, 70))
    pink = lib.material("SmoothPlastic", (255, 150, 165))
    throat = lib.material("SmoothPlastic", (92, 14, 34))
    stem = lib.material("Grass", (84, 160, 56))
    leafg = lib.material("Grass", (60, 128, 42))
    white = lib.material("SmoothPlastic", (248, 248, 238))
    black = lib.material("SmoothPlastic", (28, 24, 26))
    tongue = lib.material("SmoothPlastic", (236, 84, 120))

    # ---- base: rosette of broad leaves + two little traps ------------------------------------------------------
    bk.ellipsoid(lib, "mound", (2.4, 2.4, 0.9), (0, -0.5, 0), leafg, segs=10, rings=3, z_cut=0)
    for i in range(6):
        a = i * 60 + 30
        r = math.radians(a)
        bk.leaf(lib, "leaf%d" % i, (math.sin(r) * 0.9, -0.5 + math.cos(r) * 0.9, 0.5), a, 26, 6.0 - (i % 2) * 0.8, 3.2, 0.4,
                (leafg, stem)[i % 2], bends=[(0.4, 18), (0.7, 18)])
    for side in (-1, 1):
        base = Vector((side * 1.2, 0.2, 0.6))
        top = Vector((side * 4.2, 2.0, 3.6))
        bk.tube(lib, "babystalk%d" % side, [tuple(base), tuple((base + top) / 2 + Vector((0, 0, 0.6))), tuple(top)], [0.42, 0.36, 0.3], stem, verts=6)
        h = top + Vector((0, -0.4, 0.2))
        m = Matrix.Translation(h) @ Matrix.Rotation(math.radians(-side * 50), 4, "Z") @ Matrix.Rotation(math.radians(-20), 4, "X")
        for up, ang in ((1, 14), (-1, -8)):
            jaw(lib, "baby%d_%d" % (side, up), 1.1, 1.2, 0.75, up, ang, Vector((0, 0, 0)), red, pink, white, teeth=5,
                tooth_len=0.5, tooth_r=0.14, pre=m)

    # ---- stem --------------------------------------------------------------------------------------------------
    pts = [(0, -0.5, 0.3), (0, -0.9, 3.6), (0.1, -1.9, 6.8), (0, -2.9, 9.0), tuple(HINGE + Vector((0, -0.6, 0.4)))]
    bk.tube(lib, "stem", pts, [1.8, 1.55, 1.4, 1.35, 1.35], stem, verts=10)
    # leafy collar where the head sits on the stem
    for i in range(5):
        a = 180 + (i - 2) * 38
        r = math.radians(a)
        bk.leaf(lib, "collar%d" % i, (math.sin(r) * 0.6, HINGE.y - 0.4 + math.cos(r) * 0.6, HINGE.z - 1.0), a, -20, 3.2, 1.8, 0.3, leafg)

    # ---- head: two jaws, throat, tongue ----------------------------------------------------------------------
    rx, ry, rz = 5.0, 4.0, 2.9
    upper = jaw(lib, "upper", rx, ry, rz, 1, 30, HINGE, red, pink, white)
    lower = jaw(lib, "lower", rx * 0.96, ry * 0.95, rz * 0.9, -1, -10, HINGE, red, pink, white)
    bk.ellipsoid(lib, "throat", (3.6, 1.6, 1.7), tuple(HINGE + Vector((0, 0.9, 0.7))), throat, segs=10, rings=5)
    tg = bk.ellipsoid(lib, "tongue", (1.5, 2.5, 0.5), (0, ry * 0.95, 0.35), tongue, segs=10, rings=4)
    tg.matrix_basis = lower @ Matrix.Rotation(math.radians(6), 4, "X") @ tg.matrix_basis
    tip = bk.ellipsoid(lib, "tongue_tip", (1.25, 1.3, 0.45), (0, ry * 1.72, 0.05), tongue, segs=10, rings=4, rot=(-30, 0, 0))
    tip.matrix_basis = lower @ tip.matrix_basis

    # ---- eyes on stalks on top of the upper jaw --------------------------------------------------------------
    for side in (-1, 1):
        root = upper @ Vector((side * 1.9, ry * 0.75, rz * 0.8))
        ball = root + Vector((side * 0.3, 0.6, 2.1))
        bk.tube(lib, "eyestalk%d" % side, [tuple(root - Vector((0, 0, 0.4))), tuple(ball)], [0.55, 0.45], stem, verts=8)
        radii = (1.25, 1.1, 1.35)
        bk.ellipsoid(lib, "eyeball%d" % side, radii, tuple(ball), white, segs=12, rings=6)
        surf = bk.ellip_surface(tuple(ball), radii)
        bk.eye(lib, "eye%d" % side, surf, ball.x - side * 0.05, ball.z + 0.05, 0.85, white, black,
               look=(-side * 0.25, -0.15), brow=26, brow_mat=red, h=1.15)
