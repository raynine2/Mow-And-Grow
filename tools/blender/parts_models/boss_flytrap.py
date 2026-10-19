"""Venus Flytrap, low-part version (~18 tall): a giant carnivorous plant. Two big green jaws (magenta inside) gape
open toward the front (+Y), rimmed with long white teeth, with a dark throat and a pink tongue. Two angry eyes on
green stalks stick up behind the top jaw, glaring forward under slanted brows. A thick curved stem rises from a
rosette of broad leaves, with two little traps on short stalks at the base. About 50 parts."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _facekit as fk  # noqa: E402


def build(lib):
    green = lib.material("Grass", (64, 150, 50))
    green_d = lib.material("Grass", (46, 120, 40))
    inside = lib.material("SmoothPlastic", (200, 60, 120))
    throat = lib.material("SmoothPlastic", (60, 20, 40))
    tongue = lib.material("SmoothPlastic", (240, 110, 150))
    tooth = lib.material("SmoothPlastic", (250, 250, 245))
    white = lib.material("SmoothPlastic", (250, 250, 250))
    black = lib.material("SmoothPlastic", (30, 26, 30))
    for i in range(6):
        a = i * 60
        lib.box("leaf%d" % i, (2.4, 6.0, 0.4), lib.rotated((0, 3.6, 0.5), a), rot=(10, 0, a), mat=green if i % 2 else green_d)
    lib.cyl("stem0", 1.1, 4.6, (0, -0.6, 2.6), rot=(6, 0, 0), mat=green, verts=10)
    lib.cyl("stem1", 1.0, 4.4, (0, -1.4, 6.8), rot=(-10, 0, 0), mat=green, verts=10)
    # jaws hinged at the back (y = -2.9, z = 10.6), opening toward the front
    lib.box("lowjaw", (7.0, 6.0, 1.4), (0, 0.1, 9.6), rot=(-12, 0, 0), mat=green)
    lib.box("lowin", (6.2, 5.4, 0.3), (0, 0.2, 10.35), rot=(-12, 0, 0), mat=inside)
    lib.box("topjaw", (7.0, 6.0, 1.4), (0, 0.3, 13.6), rot=(28, 0, 0), mat=green)
    lib.box("topin", (6.2, 5.4, 0.3), (0, 0.4, 12.85), rot=(28, 0, 0), mat=inside)
    lib.box("throat", (4.2, 0.6, 2.4), (0, -2.2, 11.6), mat=throat)
    lib.box("tongue", (1.6, 3.0, 0.4), (0, 1.8, 10.9), rot=(-20, 0, 0), mat=tongue)
    for i in range(6):
        x = -2.7 + i * 1.08
        lib.wedge("ltooth%d" % i, (0.6, 0.4, 1.1), (x, 3.1, 11.1), mat=tooth)
        lib.wedge("utooth%d" % i, (0.6, 0.4, 1.1), (x, 2.9, 15.0), rot=(180, 0, 0), mat=tooth)
    for sx in (-1, 1):
        lib.cyl("stalk%d" % sx, 0.3, 2.6, (sx * 1.6, -1.2, 16.6), rot=(0, sx * 12, 0), mat=green_d, verts=8)
        lib.sphere("eye%d" % sx, 1.0, (sx * 1.9, -1.1, 18.0), mat=white)
        lib.sphere("pupil%d" % sx, 0.45, (sx * 1.6, -0.3, 18.0), mat=black)
        lib.box("brow%d" % sx, (1.8, 0.4, 0.4), (sx * 1.9, -0.8, 19.2), rot=(0, sx * 22, 0), mat=black)
        # little traps at the base
        lib.cyl("trapstalk%d" % sx, 0.25, 2.0, (sx * 4.2, 2.2, 1.0), mat=green_d, verts=8)
        lib.box("trap%d" % sx, (1.6, 1.4, 1.0), (sx * 4.2, 2.2, 2.4), rot=(15, 0, 0), mat=green)
        lib.box("trapin%d" % sx, (1.3, 1.1, 0.2), (sx * 4.2, 2.3, 2.1), rot=(15, 0, 0), mat=inside)
