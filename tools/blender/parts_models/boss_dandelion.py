"""Dandelion King, low-part version (~17.5 tall): a giant angry dandelion. A round yellow flower head ringed with
chunky yellow petals in front and golden petals behind, a crown of four upward points tipped with gold balls, an
angry face on the front (+Y), a bent green stem rising from a rosette of jagged leaves, and two leaf arms flexed out
from the stem. About 55 parts."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _facekit as fk  # noqa: E402


def build(lib):
    green = lib.material("Grass", (70, 160, 50))
    green_d = lib.material("Grass", (50, 128, 40))
    yellow = lib.material("SmoothPlastic", (255, 214, 40))
    gold = lib.material("SmoothPlastic", (240, 170, 30))
    goldball = lib.material("SmoothPlastic", (255, 190, 50))
    white = lib.material("SmoothPlastic", (250, 250, 250))
    black = lib.material("SmoothPlastic", (30, 26, 30))
    mouth = lib.material("SmoothPlastic", (110, 30, 30))
    # rosette of jagged leaves
    for i in range(6):
        a = i * 60 + 15
        lib.box("leaf%d" % i, (1.6, 5.0, 0.35), lib.rotated((0, 3.2, 0.4), a), rot=(8, 0, a), mat=green if i % 2 else green_d)
        lib.wedge("leaftip%d" % i, (1.4, 1.4, 0.35), lib.rotated((0, 6.3, 0.4), a), rot=(0, 0, a + 180), mat=green)
    lib.box("mound", (3.0, 3.0, 1.2), (0, 0, 0.6), rot=(0, 0, 20), mat=green_d)
    # bent stem in three pieces
    lib.cyl("stem0", 0.8, 4.0, (0, 0, 3.0), mat=green, verts=10)
    lib.cyl("stem1", 0.75, 3.6, (0, 0.25, 6.4), rot=(-8, 0, 0), mat=green, verts=10)
    lib.cyl("stem2", 0.7, 2.6, (0, 0.35, 8.9), rot=(5, 0, 0), mat=green, verts=10)
    for sx in (-1, 1):
        lib.box("arm%d" % sx, (3.2, 0.9, 0.4), (sx * 1.9, 0.2, 6.0), rot=(0, -sx * 35, 0), mat=green_d)
        lib.box("hand%d" % sx, (1.0, 1.0, 1.4), (sx * 3.3, 0.2, 7.3), rot=(0, -sx * 10, 0), mat=green)
    # flower head: a shaggy dandelion pom-pom, petal blocks pointing out in every direction (not a flat ring),
    # with a gap in front for the face
    hx, hy, hz = 0, 0.3, 11.6
    lib.sphere("head", 2.8, (hx, hy, hz), mat=yellow, subdiv=2)
    k = 0
    for el, n in ((-35, 8), (0, 10), (35, 8), (68, 5)):
        for i in range(n):
            a = i * 360 / n + (el % 20)
            front = math.cos(math.radians(a))  # +1 = straight at the viewer
            if front > 0.7 and abs(el) < 40:
                continue  # leave the face clear
            ra, re = math.radians(a), math.radians(el)
            d = (math.cos(re) * math.sin(ra), math.cos(re) * math.cos(ra), math.sin(re))
            lib.box("petal%d" % k, (0.9, 0.9, 2.2), (hx + d[0] * 3.2, hy + d[1] * 3.2, hz + d[2] * 3.2),
                    rot=(-(90 - el), 0, -a), mat=yellow if k % 2 else gold)
            k += 1
    # a gold crown band on top with white seed puffs on its points
    lib.cyl("crown", 1.6, 0.7, (hx, hy, hz + 3.9), mat=gold, verts=12)
    for i in range(4):
        r = math.radians(i * 90 + 45)
        px, py = hx + math.sin(r) * 1.3, hy + math.cos(r) * 1.3
        lib.box("crownpt%d" % i, (0.5, 0.5, 1.0), (px, py, hz + 4.6), mat=goldball)
        lib.sphere("puff%d" % i, 0.55, (px, py, hz + 5.4), mat=white)
    fk.face(lib, hx, hy + 2.5, hz, 1.05, white, black, black, mouth, white)
