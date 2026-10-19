"""Far-off mountain, built only from blocks and wedges so it works as native Roblox parts (tools/blender/to_parts.py):
about 60 across and 62 high. Three tiers of chunky slate blocks, each tier turned and tilted a little so the
silhouette is craggy, rocky ledges sticking out, a snow cap over the top tier with snow running down the slopes in
wedges, and a pointed snowy peak. Background scenery, no collisions needed."""
import random

PREVIEW = dict(dist=150, height=40, target_z=26, yaw=25)


def build(lib):
    rnd = random.Random(12)
    rock = lib.material("Slate", (120, 130, 145))
    rock_dark = lib.material("Slate", (96, 104, 118))
    rock_light = lib.material("Slate", (140, 148, 160))
    snow = lib.material("Snow", (240, 245, 250))
    # tiers: (size across, height, centre height, turns)
    tiers = [(46, 20, 10, (0, 30, 60)), (34, 18, 27, (15, 45, 75)), (22, 15, 42, (5, 50))]
    for t, (s, h, z, turns) in enumerate(tiers):
        for i, a in enumerate(turns):
            jitter = (rnd.uniform(-2.5, 2.5), rnd.uniform(-2.5, 2.5))
            tilt = (rnd.uniform(-5, 5), rnd.uniform(-5, 5), a + rnd.uniform(-6, 6))
            mat = (rock, rock_dark, rock_light)[(t + i) % 3]
            lib.box("tier%d_%d" % (t, i), (s * rnd.uniform(0.9, 1.05), s * rnd.uniform(0.9, 1.05), h), (jitter[0], jitter[1], z), rot=tilt, mat=mat)
    # sloped rock skirts round the two lower tiers, so the silhouette reads as a peak, not a stack of crates
    # (a wedge is tall at its -Y side: sitting on its +Y side it slopes down away from the centre)
    for i in range(9):
        a = i * 40 + rnd.uniform(-10, 10)
        lib.wedge("skirt%d" % i, (rnd.uniform(16, 20), 14, 14), lib.rotated((0, 29, 7), a), rot=(0, 0, a), mat=(rock, rock_dark)[i % 2])
    for i in range(7):
        a = i * 360 / 7 + 20 + rnd.uniform(-10, 10)
        lib.wedge("shoulder%d" % i, (rnd.uniform(12, 15), 10, 12), lib.rotated((0, 21, 24), a), rot=(0, 0, a), mat=(rock_light, rock)[i % 2])
    # rocky ledges round the lower slopes
    for i in range(6):
        a = i * 60 + rnd.uniform(-20, 20)
        r = rnd.uniform(19, 23)
        lib.box("ledge%d" % i, (9, 6, 4), lib.rotated((0, r, rnd.uniform(4, 16)), a), rot=(rnd.uniform(-10, 10), rnd.uniform(-8, 8), a), mat=rock_dark)
    # snow: a cap on the top tier, the peak, and snow running down each side
    lib.box("cap", (23, 23, 3), (0, 0, 50), rot=(2, -2, 50), mat=snow)
    lib.box("cap2", (16, 16, 4), (0, 0, 53), rot=(0, 0, 20), mat=snow)
    for i in range(4):
        a = i * 90 + 20
        # a wedge is tall at its -Y side: sitting on its +Y side it slopes down away from the centre
        lib.wedge("peak%d" % i, (10, 6, 9), lib.rotated((0, 3, 59.5), a), rot=(0, 0, a), mat=snow)
    for i in range(5):
        a = i * 72 + rnd.uniform(-10, 10)
        ln = rnd.uniform(8, 11)
        lib.wedge("drift%d" % i, (rnd.uniform(5, 7), ln, 9), lib.rotated((0, 9.5 + ln / 2, 42.5), a), rot=(0, 0, a), mat=snow)
