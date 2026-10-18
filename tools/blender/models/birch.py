"""Birch tree, matched to Chop A Forest's birch grove: a tall, slim, square white/cream trunk (Wood grain) with short
black horizontal marks on its faces, small pale root flares at the base, and a high canopy of lighter green leaf
blocks."""
import random

PREVIEW = dict(dist=70, height=17, target_z=18)

def build(lib):
    rnd = random.Random(7)
    bark = lib.material("Wood", (232, 228, 220))
    bark_root = lib.material("Wood", (218, 213, 204))
    mark = lib.material("SmoothPlastic", (28, 28, 30))
    leaf_a = lib.material("Grass", (98, 168, 58))
    leaf_b = lib.material("Grass", (116, 184, 66))
    leaf_c = lib.material("Grass", (84, 150, 50))
    w, h = 3.2, 28
    lib.box("trunk", (w, w, h), (0, 0, h / 2), mat=bark, bevel=0.12, taper=(0.9, 0.9))
    # root flares: a low sloped wedge on each side and a short flat root slab over the grass
    for i, ang in enumerate((0, 90, 180, 270)):
        a = ang + rnd.uniform(-15, 15)
        lib.wedge("buttress%d" % i, (w * 0.62, 2.8, 2.8), lib.rotated((0, w * 0.5 + 1.1, 1.35), a), rot=(0, 0, a), mat=bark, bevel=0.1)
        reach = rnd.uniform(2.0, 2.8)
        lib.box("root%d" % i, (w * 0.42, reach, 0.6), lib.rotated((rnd.uniform(-0.3, 0.3), w * 0.5 + 2.1 + reach / 2, 0.28), a),
                rot=(-3, 0, a), mat=bark_root, bevel=0.1, taper=(0.75, 1))
    # black marks: thin slabs set into each face at staggered heights (the birch "eyes")
    for i in range(14):
        face = i % 4
        z = 3.5 + i * 1.75 + rnd.uniform(-0.5, 0.5)
        half = w * 0.5 * (1 - 0.1 * z / h)  # follow the taper
        length = rnd.uniform(0.9, 1.6)
        off = rnd.uniform(-half + length / 2 + 0.2, half - length / 2 - 0.2)
        lib.box("mark%d" % i, (length, 0.16, 0.32), lib.rotated((off, half + 0.01, z), face * 90), rot=(0, 0, face * 90), mat=mark, bevel=0.03)
    # two thin branches up into the canopy
    for i, a in enumerate((60, 240)):
        lib.box("branch%d" % i, (0.9, 0.9, 6), lib.rotated((w * 0.75, 0, h * 0.86), a), rot=(0, 40, a), mat=bark, bevel=0.08)
    # canopy: narrower and taller than the oak's, lighter greens
    top = h + 1.5
    mats = [leaf_a, leaf_b, leaf_c]
    lib.box("leaf_core", (10, 10, 8), (0, 0, top + 1), rot=(rnd.uniform(-5, 5), rnd.uniform(-5, 5), rnd.uniform(0, 90)), mat=leaf_a, bevel=0.25)
    for i in range(6):
        ang = i * 60 + rnd.uniform(-12, 12)
        s = rnd.uniform(6.2, 7.5)
        lib.box("leaf%d" % i, (s, s, s * 0.8), lib.rotated((rnd.uniform(5, 6), 0, top + rnd.uniform(-1.8, 1.5)), ang),
                rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), rnd.uniform(0, 90)), mat=mats[i % 3], bevel=0.22)
    for i in range(3):
        ang = i * 120 + rnd.uniform(-20, 20)
        s = rnd.uniform(5.5, 6.5)
        lib.box("leaftop%d" % i, (s, s, s * 0.8), lib.rotated((rnd.uniform(1.8, 3), 0, top + rnd.uniform(5, 6)), ang),
                rot=(rnd.uniform(-10, 10), rnd.uniform(-10, 10), rnd.uniform(0, 90)), mat=mats[(i + 1) % 3], bevel=0.22)
