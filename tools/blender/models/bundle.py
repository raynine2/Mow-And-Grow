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
    # bristly ends: a 3 x 3 grid of stalk bunches poking out of each end by different amounts
    for side in (-1, 1):
        for j, y in enumerate((-0.42, 0.0, 0.42)):
            for k, z in enumerate((0.36, 0.84, 1.3)):
                out = rnd.uniform(0.12, 0.3)
                x = side * ((L - 0.36) / 2 - 0.15 + out / 2 + 0.15)
                lib.box("end%d_%d_%d" % (side, j, k), (out + 0.3, rnd.uniform(0.4, 0.48), rnd.uniform(0.4, 0.48)),
                        (x, y + rnd.uniform(-0.04, 0.04), z + lift + rnd.uniform(-0.04, 0.04)),
                        rot=(rnd.uniform(-6, 6), rnd.uniform(-6, 6), rnd.uniform(-5, 5)),
                        mat=(grass_lt, grass_dk, grass)[(j + k + side) % 3], bevel=0.07)
    # a few loose blades on top
    for i, (x, y, a) in enumerate(((-0.75, 0.25, 30), (0.0, -0.3, -20), (0.7, 0.2, 15))):
        lib.box("loose%d" % i, (0.16, 0.5, 0.12), (x, y, H + 0.02), rot=(0, 8, a), mat=(grass_lt, grass_dk, grass_lt)[i], bevel=0.04)
    # straps around the middle of each half, with a buckle on top
    for side in (-1, 1):
        x = side * 0.58
        lib.box("strap%d" % side, (0.32, D + 0.12, H + 0.12), (x, 0, (H + 0.12) / 2 - 0.02), mat=strap, bevel=0.07)
        lib.box("buckle%d" % side, (0.44, 0.42, 0.14), (x, 0.1, H + 0.12), mat=buckle, bevel=0.04)
