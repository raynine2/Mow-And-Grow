"""Leafy bush (~5 wide x 3 tall): a cluster of six chunky bevelled leaf blocks (a core, four tilted side blocks and a top) in three greens, like a small piece of
the oak canopy sitting on the ground."""
import random

PREVIEW = dict(dist=10, height=5.5, target_z=1.3)

def build(lib):
    rnd = random.Random(6)
    leaf_a = lib.material("Grass", (56, 126, 40))
    leaf_b = lib.material("Grass", (70, 146, 48))
    leaf_c = lib.material("Grass", (44, 106, 34))
    lib.box("core", (3.2, 2.9, 2.1), (0, 0, 1.05), rot=(0, 0, 20), mat=leaf_a, bevel=0.18)
    for i, (ang, r, s, z) in enumerate(((10, 1.35, 2.1, 1.0), (100, 1.3, 1.9, 0.9), (190, 1.4, 2.2, 1.05), (280, 1.3, 2.0, 0.95))):
        a = ang + rnd.uniform(-10, 10)
        lib.box("side%d" % i, (s, s, s * 0.85), lib.rotated((0, r, z), a),
                rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), rnd.uniform(0, 90)), mat=(leaf_b, leaf_c, leaf_b, leaf_c)[i], bevel=0.16)
    lib.box("top", (2.5, 2.4, 1.5), (0.15, -0.1, 2.15), rot=(rnd.uniform(-10, 10), rnd.uniform(-10, 10), 55), mat=leaf_b, bevel=0.18)
