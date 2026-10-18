"""Young oak: the oak at about 60% scale with a simpler canopy, for variety between the big oaks. Same square
reddish-brown trunk, root buttresses with flat root slabs, one branch, and a smaller cluster of leaf blocks."""
import random

PREVIEW = dict(dist=40, height=10, target_z=9)

def build(lib):
    rnd = random.Random(11)
    bark = lib.material("Wood", (122, 70, 48))
    bark_dark = lib.material("Wood", (106, 60, 42))
    leaf_a = lib.material("Grass", (58, 128, 40))
    leaf_b = lib.material("Grass", (72, 148, 48))
    leaf_c = lib.material("Grass", (46, 108, 36))
    w, h = 3.0, 13.5
    lib.box("trunk", (w, w, h), (0, 0, h / 2), mat=bark, bevel=0.12, taper=(0.86, 0.86))
    for i, ang in enumerate((0, 90, 180, 270)):
        a = ang + rnd.uniform(-20, 20)
        lib.wedge("buttress%d" % i, (w * 0.62, 2.5, 3.0), lib.rotated((0, w * 0.5 + 0.95, 1.45), a), rot=(0, 0, a), mat=bark, bevel=0.1)
        reach = rnd.uniform(2.3, 3.2)
        lib.box("root%d" % i, (w * 0.5, reach, 0.6), lib.rotated((rnd.uniform(-0.3, 0.3), w * 0.5 + 1.9 + reach / 2, 0.27), a),
                rot=(-3, 0, a), mat=bark_dark, bevel=0.1, taper=(0.75, 1))
    lib.box("branch", (0.9, 0.9, 5.2), lib.rotated((w * 0.95, 0, h * 0.82), 35), rot=(0, 42, 35), mat=bark, bevel=0.08)
    top = h + 1.2
    mats = [leaf_a, leaf_b, leaf_c]
    lib.box("leaf_core", (9, 9, 5.6), (0, 0, top + 0.6), rot=(rnd.uniform(-5, 5), rnd.uniform(-5, 5), rnd.uniform(0, 90)), mat=leaf_a, bevel=0.22)
    for i in range(5):
        ang = i * 72 + rnd.uniform(-12, 12)
        s = rnd.uniform(5.0, 6.2)
        lib.box("leaf%d" % i, (s, s, s * 0.78), lib.rotated((rnd.uniform(4.2, 5.2), 0, top + rnd.uniform(-1.2, 0.6)), ang),
                rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), rnd.uniform(0, 90)), mat=mats[i % 3], bevel=0.2)
    for i in range(2):
        ang = i * 180 + rnd.uniform(-25, 25)
        s = rnd.uniform(4.6, 5.4)
        lib.box("leaftop%d" % i, (s, s, s * 0.78), lib.rotated((rnd.uniform(1.4, 2.4), 0, top + rnd.uniform(3.2, 3.9)), ang),
                rot=(rnd.uniform(-10, 10), rnd.uniform(-10, 10), rnd.uniform(0, 90)), mat=mats[(i + 1) % 3], bevel=0.2)
