"""Leafy bush (~5 wide x 3 tall): a cluster of chunky bevelled leaf blocks in three greens, like a small piece of
the oak canopy sitting on the ground."""
import random

PREVIEW = dict(dist=10, height=5.5, target_z=1.3)

def build(lib):
    rnd = random.Random(6)
    leaf_a = lib.material("Grass", (56, 126, 40))
    leaf_b = lib.material("Grass", (70, 146, 48))
    leaf_c = lib.material("Grass", (44, 106, 34))
    lib.box("core", (3.4, 3.0, 2.2), (0, 0, 1.1), rot=(0, 0, 20), mat=leaf_a, bevel=0.18)
    for i, (ang, r, s, z) in enumerate(((10, 1.3, 2.1, 1.0), (130, 1.4, 2.3, 1.05), (250, 1.25, 2.0, 0.95))):
        a = ang + rnd.uniform(-10, 10)
        lib.box("side%d" % i, (s, s, s * 0.85), lib.rotated((0, r, z), a),
                rot=(rnd.uniform(-8, 8), rnd.uniform(-8, 8), rnd.uniform(0, 90)), mat=(leaf_b, leaf_c, leaf_b)[i], bevel=0.16)
    lib.box("top", (2.2, 2.0, 1.4), (0.2, -0.1, 2.3), rot=(rnd.uniform(-6, 6), rnd.uniform(-6, 6), 55), mat=leaf_b, bevel=0.16)
