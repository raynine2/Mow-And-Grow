"""Giant jungle tree for the Mega Jungle zone: a huge tapering trunk (about 46 tall) with tall fin-shaped buttress
roots, three branches, hanging vines, and three stacked tiers of broad flat leaf blocks."""
import random

PREVIEW = dict(dist=95, height=26, target_z=24, yaw=30)


def build(lib):
    rnd = random.Random(19)
    bark = lib.material("Wood", (96, 66, 44))
    bark_dark = lib.material("Wood", (78, 52, 36))
    vine = lib.material("Grass", (40, 120, 44))
    leaf_a = lib.material("Grass", (24, 104, 42))
    leaf_b = lib.material("Grass", (34, 124, 50))
    leaf_c = lib.material("Grass", (18, 88, 36))
    w, h = 7.0, 40
    lib.box("trunk", (w, w, h), (0, 0, h / 2), rot=(0, 0, 8), mat=bark, bevel=0.3, taper=(0.72, 0.72))
    for i in range(6):
        a = i * 60 + rnd.uniform(-12, 12)
        lib.wedge("fin%d" % i, (1.1, 7.5, 9.0), lib.rotated((0, w * 0.45 + 3.2, 4.5), a), rot=(0, 0, a), mat=bark_dark, bevel=0.15)
    for i, (a, z) in enumerate([(20, 26), (140, 31), (260, 35)]):
        lib.box("branch%d" % i, (1.8, 1.8, 13), lib.rotated((w * 0.9, 0, z), a), rot=(0, 55, a), mat=bark, bevel=0.12)
    mats = [leaf_a, leaf_b, leaf_c]
    tiers = [(30, 26, 8), (38, 20, 7), (45, 14, 6)]
    for t, (z, size, n) in enumerate(tiers):
        lib.box("tier%d" % t, (size, size, 3.6), (0, 0, z), rot=(0, 0, rnd.uniform(0, 90)), mat=mats[t % 3], bevel=0.4)
        for i in range(n):
            a = i * 360 / n + rnd.uniform(-15, 15)
            s = rnd.uniform(size * 0.32, size * 0.42)
            lib.box("leaf%d_%d" % (t, i), (s, s, 3.0), lib.rotated((size * 0.48, 0, z + rnd.uniform(-1.2, 1.2)), a),
                    rot=(rnd.uniform(-8, 8), rnd.uniform(-8, 8), rnd.uniform(0, 90)), mat=mats[(i + t) % 3], bevel=0.3)
    for i in range(9):
        a = rnd.uniform(0, 360)
        r = rnd.uniform(6, 12)
        ln = rnd.uniform(8, 16)
        lib.box("vine%d" % i, (0.35, 0.35, ln), lib.rotated((r, 0, 28 - ln / 2), a), mat=vine)
