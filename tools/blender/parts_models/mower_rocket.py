"""Rocket Mower, low-part version (~6 wide x 10 long x 5.2 tall): a sleek red-orange sci-fi racer that is still a
ride-on mower. A pointed nose with cyan light slits, low slick tyres with glowing cyan rims, a glass windscreen, a
high-back seat, two white-banded booster rockets on the rear fenders with tail fins and orange Neon flames, a spoiler
wing, and a wide deck out front with a glowing cyan edge. Front +Y, wheels on z = 0, seat cushion top at z = 3 around
(0, -1)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _mowerkit as kit  # noqa: E402


def build(lib):
    red = lib.material("SmoothPlastic", (230, 70, 40))
    orange = lib.material("SmoothPlastic", (255, 130, 40))
    tyre = lib.material("SmoothPlastic", (30, 30, 34))
    cyan = lib.material("Neon", (60, 230, 255))
    white = lib.material("SmoothPlastic", (240, 240, 245))
    glass = lib.material("Glass", (170, 220, 255), transparency=0.4)
    flame = lib.material("Neon", (255, 150, 40))
    black = lib.material("SmoothPlastic", (40, 40, 46))
    for sx in (-1, 1):
        kit.wheel(lib, "rear%d" % sx, sx * 2.55, -2.8, 1.25, 1.0, tyre, cyan)
        kit.wheel(lib, "front%d" % sx, sx * 2.35, 2.4, 0.9, 0.8, tyre, cyan)
        lib.box("fender%d" % sx, (1.3, 3.0, 0.35), (sx * 2.55, -2.8, 2.7), mat=red)
        lib.cyl("booster%d" % sx, 0.6, 3.2, (sx * 2.55, -3.4, 3.5), rot=(90, 0, 0), mat=white, verts=12)
        lib.cyl("band%d" % sx, 0.63, 0.5, (sx * 2.55, -2.6, 3.5), rot=(90, 0, 0), mat=red, verts=12)
        lib.cyl("flame%d" % sx, 0.42, 1.2, (sx * 2.55, -5.6, 3.5), rot=(90, 0, 0), mat=flame, verts=10)
        lib.wedge("fin%d" % sx, (0.15, 1.6, 1.4), (sx * 2.55, -4.0, 4.6), mat=orange)
        lib.box("slit%d" % sx, (0.6, 0.1, 0.12), (sx * 0.7, 4.3, 1.75), mat=cyan)
    lib.box("body", (3.2, 7.6, 1.1), (0, -0.2, 1.65), mat=red)
    lib.wedge("nose", (3.0, 2.2, 1.1), (0, 4.0, 1.65), rot=(0, 0, 180), mat=orange)
    lib.box("windscreen", (2.4, 0.15, 1.1), (0, 0.6, 3.1), rot=(20, 0, 0), mat=glass)
    lib.box("spoiler", (5.4, 0.9, 0.2), (0, -4.6, 5.0), mat=orange)
    for sx in (-1, 1):
        lib.box("strut%d" % sx, (0.2, 0.2, 1.2), (sx * 1.8, -4.6, 4.3), mat=black)
    kit.seat(lib, black, red)
    kit.deck(lib, 6.0, 2.4, 1.4, 0.8, red, cyan, black, n=6)
