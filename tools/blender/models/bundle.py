"""Grass bundle: the "log" of Mow A Lawn, carried on the back and sold. A chunky bale of cut grass (2.4 x 1.4 x 1.6)
with bristly cut-stalk ends sticking out of both sides and a few loose blades on top, tied with two yellow-brown
straps that each have a buckle block on top."""
import random

PREVIEW = dict(dist=6.5, height=3.6, target_z=0.8, yaw=38)

def build(lib):
    rnd = random.Random(2)
    grass = lib.material("Grass", (92, 162, 48))
    grass_lt = lib.material("Grass", (118, 184, 60))
    grass_dk = lib.material("Grass", (72, 136, 40))
    strap = lib.material("Fabric", (204, 156, 62))
    buckle = lib.material("WoodPlanks", (150, 102, 48))
    L, D, H = 2.4, 1.4, 1.6
    lift = 0.05  # so the straps, not the grass, touch the ground
    lib.box("bale", (L - 0.36, D, H - lift), (0, 0, lift + (H - lift) / 2), mat=grass, bevel=0.22)
    # bristly ends: a 4 x 3 grid of cut stalk bunches poking out of each end by different amounts
    core_x = (L - 0.36) / 2
    for side in (-1, 1):
        for j, y in enumerate((-0.48, -0.16, 0.16, 0.48)):
            for k, z in enumerate((0.34, 0.82, 1.28)):
                out = rnd.uniform(0.1, 0.34)
                lib.box("end%d_%d_%d" % (side, j, k), (out + 0.25, rnd.uniform(0.3, 0.36), rnd.uniform(0.38, 0.46)),
                        (side * (core_x - 0.12 + (out + 0.25) / 2), y + rnd.uniform(-0.03, 0.03), z + lift + rnd.uniform(-0.04, 0.04)),
                        rot=(rnd.uniform(-8, 8), rnd.uniform(-8, 8), rnd.uniform(-6, 6)),
                        mat=(grass_lt, grass_dk, grass)[(j + k + (side > 0)) % 3], bevel=0.06)
    # long blades poking out of the ends and the top, so it reads as a bundle of cut grass, not a box
    for i, (x, y, z, ry, rz) in enumerate(((-1.35, 0.3, 1.55, -35, 10), (1.38, -0.35, 1.5, 38, -12), (-1.3, -0.45, 0.95, -60, -15),
                                           (1.32, 0.42, 0.7, 62, 14), (0.05, -0.45, 1.68, 20, 70), (-0.2, 0.4, 1.7, -24, 100))):
        lib.box("blade%d" % i, (0.62, 0.16, 0.1), (x, y, z), rot=(0, ry, rz), mat=(grass_lt, grass_dk)[i % 2], bevel=0.04, taper=(0.4, 1))
    # straps around the middle of each half, with a buckle on top
    for side in (-1, 1):
        x = side * 0.58
        lib.box("strap%d" % side, (0.32, D + 0.12, H + 0.12), (x, 0, (H + 0.12) / 2 - 0.02), mat=strap, bevel=0.07)
        lib.box("buckle%d" % side, (0.44, 0.42, 0.14), (x, 0.1, H + 0.12), mat=buckle, bevel=0.04)
