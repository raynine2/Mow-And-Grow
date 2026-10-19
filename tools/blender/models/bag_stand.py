"""Bag Stand (run hub): a small wooden market stall where you buy bigger bags. A plank counter with a striped canvas
awning on four posts, a blank sign board on top (text is added in-game), and three round tree-stump pedestals in
front where the bag models stand (pedestal tops at z = 2.0, at x = -5, 0, 5, y = 4.5). Faces +Y."""
PREVIEW = dict(dist=26, height=10, target_z=4.5, yaw=25)

PEDESTALS = [(-5.0, 4.5), (0.0, 4.5), (5.0, 4.5)]


def build(lib):
    post = lib.material("Wood", (168, 112, 66))
    plank = lib.material("WoodPlanks", (196, 140, 88))
    plank_dark = lib.material("WoodPlanks", (140, 94, 58))
    canvas_a = lib.material("Fabric", (90, 190, 90))
    canvas_b = lib.material("Fabric", (245, 240, 225))
    bark = lib.material("Wood", (122, 80, 52))
    rings = lib.material("Wood", (222, 188, 140))
    W, D = 14.0, 4.0
    # counter: plank front + top
    lib.box("counter", (W - 1.6, 1.4, 3.2), (0, 0.6, 1.6), mat=plank, bevel=0.08)
    lib.box("counter_top", (W - 1.0, 2.2, 0.35), (0, 0.6, 3.35), mat=plank_dark, bevel=0.08)
    for i in range(6):
        lib.box("slat%d" % i, (0.12, 1.45, 3.0), (-W / 2 + 1.6 + i * 2.15, 1.32, 1.6), mat=plank_dark)
    # back wall and four posts
    lib.box("back", (W - 1.0, 0.4, 7.4), (0, -D / 2, 3.7), mat=plank, bevel=0.06)
    for sx in (-1, 1):
        for y in (-D / 2, 1.4):
            lib.box("post%d_%d" % (sx, int(y * 10)), (0.8, 0.8, 8.0), (sx * (W / 2 - 0.4), y, 4.0), mat=post, bevel=0.1)
    # striped canvas awning sloping to the front
    stripes = 7
    sw = (W + 1.0) / stripes
    for i in range(stripes):
        x = -(W + 1.0) / 2 + sw * (i + 0.5)
        lib.box("awning%d" % i, (sw + 0.02, 5.4, 0.25), (x, -0.1, 8.25), rot=(-14, 0, 0), mat=canvas_a if i % 2 == 0 else canvas_b)
        # scalloped edge flap
        lib.box("flap%d" % i, (sw * 0.86, 0.2, 0.9), (x, 2.55, 7.25), mat=canvas_a if i % 2 == 0 else canvas_b, bevel=0.08)
    # sign board above the awning
    lib.box("sign", (10.0, 0.5, 2.6), (0, -1.2, 10.6), mat=plank_dark, bevel=0.12)
    for sx in (-1, 1):
        lib.box("sign_leg%d" % sx, (0.5, 0.5, 2.2), (sx * 3.5, -1.2, 9.0), mat=post)
    # pedestals: round stumps with cut rings on top
    for i, (x, y) in enumerate(PEDESTALS):
        lib.cyl("stump%d" % i, 1.35, 2.0, (x, y, 1.0), mat=bark, verts=12, bevel=0.08)
        lib.cyl("rings%d" % i, 1.18, 0.06, (x, y, 2.02), mat=rings, verts=12)
