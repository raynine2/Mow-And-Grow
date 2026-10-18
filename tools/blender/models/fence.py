"""Rustic fence segment, 8 studs long along X (tiles every 8): two square posts and two plank rails on the front
(+Y), slightly uneven like the lobby / field fences in Chop A Forest."""
PREVIEW = dict(dist=12, height=4, target_z=2, yaw=30)


def build(lib):
    post = lib.material("Wood", (138, 92, 56))
    rail = lib.material("WoodPlanks", (160, 108, 66))
    for i, x in enumerate((-3.6, 3.6)):
        lib.box("post%d" % i, (0.75, 0.75, 4.2 - 0.15 * i), (x, 0, (4.2 - 0.15 * i) / 2), mat=post, bevel=0.1, taper=(0.92, 0.92))
        lib.box("postcap%d" % i, (0.85, 0.85, 0.2), (x, 0, 4.2 - 0.15 * i), rot=(0, 0, 4), mat=post, bevel=0.06)
    lib.box("rail_top", (8.0, 0.35, 0.7), (0, 0.5, 3.2), rot=(0, 0.6, 0), mat=rail, bevel=0.08)
    lib.box("rail_low", (8.0, 0.35, 0.7), (0, 0.5, 1.6), rot=(0, -0.5, 0), mat=rail, bevel=0.08)
