"""Wheat Farm hay bale: a chunky rectangular bale (4 x 4 x 3.6) of golden straw with two twine bands, loose straw
tufts sticking out of the top and a few bits on the ground."""
import random

PREVIEW = dict(dist=12, height=5, target_z=1.8, yaw=35)


def build(lib):
    rnd = random.Random(3)
    straw = lib.material("Fabric", (235, 190, 70))
    straw_dark = lib.material("Fabric", (210, 162, 54))
    twine = lib.material("Fabric", (150, 98, 52))
    lib.box("bale", (4.0, 4.0, 3.6), (0, 0, 1.8), mat=straw, bevel=0.35)
    lib.box("bale_top", (3.6, 3.6, 0.3), (0, 0, 3.62), mat=straw_dark, bevel=0.12)
    for i, x in enumerate((-1.0, 1.0)):
        lib.box("band%d" % i, (0.22, 4.08, 3.68), (x, 0, 1.8), mat=twine, bevel=0.06)
    for i in range(9):
        lib.box("tuft%d" % i, (0.2, 0.2, rnd.uniform(0.5, 1.0)), (rnd.uniform(-1.6, 1.6), rnd.uniform(-1.6, 1.6), 3.8),
                rot=(rnd.uniform(-35, 35), rnd.uniform(-35, 35), rnd.uniform(0, 90)), mat=straw if i % 2 else straw_dark)
    for i in range(6):
        lib.box("bit%d" % i, (0.15, rnd.uniform(0.6, 1.1), 0.08), (rnd.uniform(-3, 3), rnd.uniform(-3, 3), 0.04),
                rot=(0, 0, rnd.uniform(0, 180)), mat=straw_dark)
