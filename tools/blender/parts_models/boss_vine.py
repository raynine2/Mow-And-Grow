"""Swamp Vine, low-part version (~20 tall): a murky purple tangle. Four thick vines twist up out of a muddy clump
with reeds and braid into a purple bulb head with a crest of dark thorn-leaves, two glowing green Neon eyes under
heavy brows and a jagged grin of crooked fangs on the front (+Y). Leaves sprout off the vines, two tendril arms curl
out to the sides and swamp moss hangs off the head. About 55 parts."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _facekit as fk  # noqa: E402


def build(lib):
    vine = lib.material("SmoothPlastic", (110, 70, 140))
    vine_d = lib.material("SmoothPlastic", (80, 50, 110))
    leaf = lib.material("Grass", (90, 130, 70))
    moss = lib.material("Grass", (110, 140, 80))
    mud = lib.material("Mud", (90, 74, 56))
    reed = lib.material("Grass", (84, 140, 76))
    glow = lib.material("Neon", (120, 255, 90))
    black = lib.material("SmoothPlastic", (30, 26, 34))
    fang = lib.material("SmoothPlastic", (236, 232, 210))
    lib.box("mud", (6.0, 6.0, 1.6), (0, 0, 0.8), rot=(0, 0, 20), mat=mud)
    for i in range(4):
        lib.box("reed%d" % i, (0.25, 0.25, 3.0), lib.rotated((0, 2.6, 2.2), i * 90 + 45), rot=(10, 0, i * 90 + 45), mat=reed)
    # four vines in three twisting segments each
    for v in range(4):
        base = v * 90
        for s in range(3):
            a = math.radians(base + s * 35)
            r = 1.6 - s * 0.35
            lib.cyl("vine%d_%d" % (v, s), 0.75 - s * 0.08, 4.4, (math.sin(a) * r, math.cos(a) * r, 3.4 + s * 3.9), rot=(math.cos(a) * 14, -math.sin(a) * 14, 0), mat=vine if (v + s) % 2 else vine_d, verts=8)
        lib.box("vleaf%d" % v, (1.6, 0.25, 0.9), (math.sin(math.radians(base + 20)) * 2.4, math.cos(math.radians(base + 20)) * 2.4, 6.5), rot=(0, 30, base), mat=leaf)
    hx, hy, hz = 0, 0.4, 15.4
    lib.sphere("head", 3.6, (hx, hy, hz), mat=vine, subdiv=2)
    for i in range(5):
        a = -40 + i * 20
        lib.wedge("crest%d" % i, (1.1, 1.6, 2.4), (hx + math.sin(math.radians(a)) * 2.6, hy - 1.0, hz + 3.4), rot=(0, a, 0), mat=vine_d)
    for sx in (-1, 1):
        lib.box("ear%d" % sx, (2.6, 0.4, 1.2), (hx + sx * 3.8, hy, hz + 0.2), rot=(0, sx * 30, 0), mat=leaf)
        # a tendril arm in joined pieces: out from the side of the head, then curling down at the end
        pts = [(sx * 3.0, 13.2), (sx * 6.4, 12.4), (sx * 8.4, 10.2), (sx * 8.6, 8.4)]
        for s in range(3):
            (x0, z0), (x1, z1) = pts[s], pts[s + 1]
            ln = math.hypot(x1 - x0, z1 - z0)
            ang = -math.degrees(math.atan2(z1 - z0, x1 - x0))
            lib.box("tendril%d_%d" % (sx, s), (ln + 0.5, 0.7 - s * 0.1, 0.7 - s * 0.1), ((x0 + x1) / 2, 0.4, (z0 + z1) / 2), rot=(0, ang, 0), mat=vine_d)
    # moss hanging straight off the bottom of the head
    for i in range(4):
        mx = hx - 1.5 + i * 1.0
        lib.box("moss%d" % i, (0.35, 0.3, 2.0), (mx, hy + 1.2, hz - 3.6), mat=moss)
    fk.face(lib, hx, hy + 3.2, hz + 0.2, 1.15, glow, black, black, black, fang, teeth=5, glow=True)
