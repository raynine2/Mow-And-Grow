"""Leaf Vacuum (hand tool, coin shop): sucks up cut-grass bundles from around you. An orange motor housing with a
black handle on top (the grip, at the origin), a long black suction tube along +Y ending in a flared green
nozzle, and a fat mesh collection bag hanging under the motor."""
PREVIEW = dict(dist=10.0, height=1.5, target_z=-1.2, yaw=62, ground=False)


def build(lib):
    body = lib.material("SmoothPlastic", (255, 140, 40))
    body_dark = lib.material("SmoothPlastic", (220, 110, 30))
    black = lib.material("SmoothPlastic", (34, 34, 38))
    nozzle = lib.material("SmoothPlastic", (80, 200, 90))
    bag = lib.material("Fabric", (90, 96, 104))
    metal = lib.material("Metal", (190, 190, 200))
    # grip (origin) with a trigger, sitting on top of the motor
    lib.box("grip", (0.5, 1.6, 0.5), (0, 0, 0), mat=black, bevel=0.12)
    lib.box("trigger", (0.25, 0.35, 0.4), (0, 0.3, -0.38), mat=body_dark, bevel=0.05)
    for y in (-0.7, 0.7):
        lib.box("grip_post%d" % int(y * 10), (0.4, 0.3, 0.7), (0, y, -0.45), mat=black, bevel=0.06)
    # motor housing
    lib.box("motor", (1.3, 2.0, 1.2), (0, 0, -1.25), mat=body, bevel=0.3)
    lib.box("vent", (1.34, 0.9, 0.5), (0, -0.4, -1.0), mat=body_dark, bevel=0.1)
    lib.cyl("fan", 0.55, 0.2, (0.68, -0.3, -1.25), rot=(0, 90, 0), mat=metal, verts=12)
    # suction tube along +Y and the flared nozzle
    lib.cyl("tube", 0.32, 4.4, (0, 3.1, -1.35), rot=(-90, 0, 0), mat=black, verts=12)
    lib.cyl("collar", 0.42, 0.35, (0, 1.05, -1.35), rot=(-90, 0, 0), mat=metal, verts=12)
    lib.cyl("nozzle", 0.38, 1.0, (0, 5.75, -1.35), rot=(-90, 0, 0), mat=nozzle, verts=12, top_scale=1.9)
    lib.cyl("lip", 0.75, 0.15, (0, 6.28, -1.35), rot=(-90, 0, 0), mat=body_dark, verts=12)
    # collection bag under the motor
    lib.sphere("bag", 0.85, (0, -0.3, -2.45), mat=bag, subdiv=2)
    lib.cyl("bag_ring", 0.55, 0.2, (0, -0.3, -1.85), mat=metal, verts=12)
