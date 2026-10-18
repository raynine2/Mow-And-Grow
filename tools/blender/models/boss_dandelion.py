"""Dandelion King, the zone 1 boss (Backyard Lawn), ~17.5 tall.

A giant angry dandelion: a round yellow flower head (two rings of chunky petals, yellow in front and golden behind,
with the top petals stretched up into a crown of points tipped with gold balls) and green sepals peeling back
behind it. The angry cartoon face (white eyes with pupils glaring inward, slanted black brows, an open toothy
snarl) is on the front (+Y). A thick bent green stem rises from a leafy mound inside a rosette of jagged dandelion
leaves, with two leaves sticking out of the stem like flexed arms.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _bosskit as bk  # noqa: E402

PREVIEW = dict(dist=31, height=10.5, target_z=8.5, yaw=32)

HEAD = (0, 0.3, 11.6)


def build(lib):
    yellow = lib.material("SmoothPlastic", (255, 226, 70))
    fuzz = lib.material("Fabric", (255, 220, 40))
    gold = lib.material("SmoothPlastic", (245, 160, 20))
    stem = lib.material("Grass", (86, 168, 52))
    leafg = lib.material("Grass", (58, 134, 40))
    white = lib.material("SmoothPlastic", (248, 248, 240))
    black = lib.material("SmoothPlastic", (30, 24, 28))
    mouth_in = lib.material("SmoothPlastic", (120, 24, 36))

    # ---- ground: dirt mound + rosette of jagged leaves ------------------------------------------------------
    bk.ellipsoid(lib, "mound", (2.8, 2.8, 1.0), (0, 0, 0), leafg, segs=10, rings=3, z_cut=0)
    for i in range(7):
        a = i * 360 / 7 + 12
        r = math.radians(a)
        bk.leaf(lib, "rosette%d" % i, (math.sin(r) * 0.8, math.cos(r) * 0.8, 0.45), a, 24, 6.4 - (i % 2) * 0.8, 2.6, 0.35,
                (leafg, stem)[i % 2], teeth=4, tooth=0.4, bends=[(0.5, 32)])

    # ---- stem: thick, a little bent, wider at the bottom ---------------------------------------------------------
    pts = [(0, 0, 0.2), (0.15, -0.35, 3.2), (-0.1, -0.2, 6.2), (0, 0.1, 9.0), (0, 0.2, 10.5)]
    bk.tube(lib, "stem", pts, [1.9, 1.6, 1.4, 1.3, 1.25], stem, verts=10)
    # arm leaves, flexed up and out
    for side in (-1, 1):
        bk.leaf(lib, "arm%d" % side, (side * 0.9, -0.3, 5.4), side * 90, 28, 6.0, 2.5, 0.4, leafg, teeth=3, tooth=0.4,
                bends=[(0.45, -45)])

    # ---- head ------------------------------------------------------------------------------------------------
    hx, hy, hz = HEAD
    # green sepals peeling back behind the flower
    for i in range(10):
        a = i * 36 + 18
        r = math.radians(a)
        o = lib.box("sepal%d" % i, (1.1, 0.35, 3.0), (0, 0, 1.5), mat=stem, taper=(0.3, 1))
        bk._xform(o, (0, 0, 0), (35, 0, 0))
        bk._xform(o, (hx + math.sin(r) * 1.6, hy - 1.2, hz + math.cos(r) * 1.6), (0, a, 0))
    # two rings of petals in the XZ plane, the top ones longer (a crown)
    for ring, (n, rad, y, mat, scale, off) in enumerate(((16, 2.5, -0.55, gold, 1.0, 0.0), (14, 2.6, 0.15, yellow, 0.82, 0.5))):
        for i in range(n):
            phi = (i + off) * 360 / n
            up = (1 + math.cos(math.radians(phi))) / 2          # 1 at the top, 0 at the bottom
            length = (2.3 + 1.5 * up ** 2) * scale
            crown = ring == 0 and up > 0.8
            if crown:
                length += 1.4
            w = 1.55 if not crown else 1.7
            o = lib.box("petal%d_%d" % (ring, i), (w, 0.7, length), (0, 0, length / 2), mat=mat, bevel=0.14,
                        taper=(0.3, 0.7) if crown else (0.72, 0.8))
            # tip a little toward the viewer so the flower is cupped
            bk._xform(o, (0, 0, 0), (-12 if ring else -6, 0, 0))
            p = (hx + math.sin(math.radians(phi)) * rad, hy + y, hz + math.cos(math.radians(phi)) * rad)
            bk._xform(o, p, (0, phi, 0))
            if crown:
                tip = o.matrix_basis @ bk.Vector((0, 0, length / 2 + 0.25))
                lib.sphere("jewel%d" % i, 0.42, tuple(tip), mat=gold, subdiv=1)
    # fuzzy centre the face sits on
    radii = (3.3, 2.0, 3.1)
    bk.ellipsoid(lib, "core", radii, HEAD, fuzz, segs=14, rings=7)
    surf = bk.ellip_surface(HEAD, radii)

    # ---- face ------------------------------------------------------------------------------------------------
    for side in (-1, 1):
        bk.eye(lib, "eye%d" % side, surf, side * 1.32, hz + 0.85, 1.0, white, black, look=(-side * 0.22, -0.1),
               brow=24, brow_mat=black, h=1.18)
    bk.mouth(lib, "mouth", surf, hz - 1.35, 3.9, 1.8, mouth_in, white, top_teeth=4, bottom_teeth=2, frown=0.3)
    bk.scale_all(0.88)
