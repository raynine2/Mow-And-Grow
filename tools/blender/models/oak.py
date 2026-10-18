"""Oak tree, matched to Chop A Forest screenshots: thick square reddish-brown trunk that flares out at the base
into big root buttresses with flat root slabs over the grass, two branches, and a wide high canopy of chunky
leaf blocks."""
import random

PREVIEW = dict(dist=62, height=16, target_z=15)

def build(lib):
    rnd = random.Random(4)
    bark = lib.material("Wood", (122, 70, 48))
    bark_dark = lib.material("Wood", (106, 60, 42))
    leaf_a = lib.material("Grass", (52, 120, 38))
    leaf_b = lib.material("Grass", (66, 140, 46))
    leaf_c = lib.material("Grass", (42, 102, 34))
    w, h = 5.0, 23
    # trunk, slightly narrower at the top
    lib.box("trunk", (w, w, h), (0, 0, h / 2), mat=bark, bevel=0.15, taper=(0.86, 0.86))
    # buttresses: a tall sloped block on each side that widens the base, then a flat slab out over the ground
    for i, ang in enumerate((0, 90, 180, 270)):
        a = ang + rnd.uniform(-20, 20)
        lib.wedge("buttress%d" % i, (w * 0.62, 4.2, 5.0), lib.rotated((0, w * 0.5 + 1.6, 2.4), a), rot=(0, 0, a), mat=bark, bevel=0.12)
        reach = rnd.uniform(4.0, 5.5)
        lib.box("root%d" % i, (w * 0.5, reach, 0.9), lib.rotated((rnd.uniform(-0.5, 0.5), w * 0.5 + 3.2 + reach / 2, 0.4), a),
                rot=(-3, 0, a), mat=bark_dark, bevel=0.12, taper=(0.75, 1))
    # branches reaching up into the canopy
    for i, a in enumerate((30, 210)):
        lib.box("branch%d" % i, (1.5, 1.5, 9), lib.rotated((w * 0.95, 0, h * 0.8), a), rot=(0, 42, a), mat=bark, bevel=0.1)
    # canopy
    top = h + 2
    mats = [leaf_a, leaf_b, leaf_c]
    lib.box("leaf_core", (15, 15, 9), (0, 0, top + 1), rot=(rnd.uniform(-5, 5), rnd.uniform(-5, 5), rnd.uniform(0, 90)), mat=leaf_a, bevel=0.3)
    for i in range(8):
        ang = i * 45 + rnd.uniform(-14, 14)
        s = rnd.uniform(8, 10.5)
        lib.box("leaf%d" % i, (s, s, s * 0.78), lib.rotated((rnd.uniform(7, 8.8), 0, top + rnd.uniform(-2.2, 1)), ang),
                rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), rnd.uniform(0, 90)), mat=mats[i % 3], bevel=0.25)
    for i in range(4):
        ang = i * 90 + rnd.uniform(-25, 25)
        s = rnd.uniform(7, 8.5)
        lib.box("leaftop%d" % i, (s, s, s * 0.78), lib.rotated((rnd.uniform(2.5, 4.5), 0, top + rnd.uniform(5, 6.5)), ang),
                rot=(rnd.uniform(-10, 10), rnd.uniform(-10, 10), rnd.uniform(0, 90)), mat=mats[(i + 1) % 3], bevel=0.25)
