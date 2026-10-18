"""A cut log lying on the ground, like the logs that fall in Chop A Forest: a round reddish-brown bark cylinder
along X (6 long, radius 1) with light tan cut ends that show a darker growth ring, and a small knot stub."""

PREVIEW = dict(dist=11, height=5, target_z=1.0, yaw=30)

def build(lib):
    bark = lib.material("Wood", (122, 70, 48))
    cut = lib.material("WoodPlanks", (222, 184, 128))
    ring = lib.material("WoodPlanks", (196, 150, 96))
    r, length = 1.0, 6.0
    lib.cyl("bark", r, length, (0, 0, r), rot=(0, 90, 0), mat=bark, verts=14, bevel=0.06)
    for side in (-1, 1):
        x = side * (length / 2 + 0.02)
        lib.cyl("end%d" % side, r * 0.86, 0.12, (x, 0, r), rot=(0, 90, 0), mat=cut, verts=14, bevel=0.03)
        lib.cyl("ring%d" % side, r * 0.5, 0.12, (x + side * 0.04, 0, r), rot=(0, 90, 0), mat=ring, verts=12)
        lib.cyl("heart%d" % side, r * 0.3, 0.12, (x + side * 0.07, 0, r), rot=(0, 90, 0), mat=cut, verts=10)
    # a short sawn-off branch stub on the top for character
    lib.cyl("knot", 0.32, 0.7, (0.9, -0.3, r * 1.85), rot=(-15, 0, 0), mat=bark, verts=8, bevel=0.04)
    lib.cyl("knot_end", 0.24, 0.06, (0.9, -0.39, r * 1.85 + 0.34), rot=(-15, 0, 0), mat=cut, verts=8)
