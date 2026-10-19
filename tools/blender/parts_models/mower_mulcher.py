"""Monster Mulcher, low-part version (~6.6 wide x 9.9 long x 7 tall): a heavy purple industrial mulcher. Four huge
tyres with yellow hubs, a tall purple hood with a black grille and amber work lights, twin black exhaust stacks, a roll
cage with a roof and an orange beacon, a yellow counterweight at the back, and out front a toothed mulching drum
under a purple housing with a hazard-striped lip. Front +Y, wheels on z = 0, seat cushion top at z = 3 around (0, -1)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _mowerkit as kit  # noqa: E402


def build(lib):
    purple = lib.material("SmoothPlastic", (130, 70, 210))
    purple_d = lib.material("SmoothPlastic", (100, 50, 170))
    tyre = lib.material("SmoothPlastic", (34, 34, 38))
    yellow = lib.material("SmoothPlastic", (250, 206, 30))
    black = lib.material("SmoothPlastic", (40, 40, 46))
    steel = lib.material("Metal", (180, 185, 195))
    amber = lib.material("Neon", (255, 170, 40))
    beacon = lib.material("Neon", (255, 120, 30))
    for sx in (-1, 1):
        for sy, r in ((-2.6, 1.7), (2.2, 1.5)):
            kit.wheel(lib, "tyre%d_%d" % (sx, int(sy)), sx * 2.85, sy, r, 1.3, tyre, yellow)
        for py in (-2.6, -0.2):
            lib.box("cage%d_%d" % (sx, int(py * 10)), (0.25, 0.25, 3.8), (sx * 1.6, py - 1.0, 4.6), mat=black)
        lib.cyl("stack%d" % sx, 0.22, 2.4, (sx * 0.9, 1.6, 4.9), mat=black, verts=8)
        lib.box("worklight%d" % sx, (0.45, 0.2, 0.35), (sx * 1.1, 3.6, 3.7), mat=amber)
    lib.box("chassis", (3.6, 8.0, 1.0), (0, -0.2, 1.7), mat=purple_d)
    lib.box("hood", (3.0, 3.2, 1.9), (0, 2.0, 3.05), mat=purple)
    lib.box("grille", (2.4, 0.2, 1.3), (0, 3.65, 3.0), mat=black)
    lib.box("roof", (3.6, 3.0, 0.3), (0, -2.3, 6.6), mat=purple)
    lib.cyl("beacon", 0.35, 0.5, (0, -2.3, 7.0), mat=beacon, verts=8)
    lib.box("counterweight", (3.4, 1.0, 1.6), (0, -4.7, 1.9), mat=yellow)
    kit.seat(lib, black, black, w=2.4)
    lib.box("housing", (6.6, 1.8, 1.6), (0, 4.6, 1.4), mat=purple)
    lib.cyl("drum", 0.65, 6.2, (0, 4.75, 0.7), rot=(0, 90, 0), mat=steel, verts=12)
    for i in range(6):
        lib.box("tooth%d" % i, (0.35, 0.5, 0.5), (-2.6 + i * 1.04, 5.35, 0.55), rot=(45, 0, 0), mat=steel)
    for i in range(6):
        lib.box("lip%d" % i, (1.1, 0.25, 0.4), (-2.75 + i * 1.1, 5.55, 2.0), mat=yellow if i % 2 == 0 else black)
