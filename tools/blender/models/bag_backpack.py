"""Bag tier 2, the Clipping Backpack: a green canvas backpack with a big front pocket, two side pockets, padded
shoulder straps on the back and a rolled blanket strapped on top. About 2.4 x 1.4 x 3 studs, front +Y."""
PREVIEW = dict(dist=7.5, height=2.8, target_z=1.4, yaw=35)


def build(lib):
    canvas = lib.material("Fabric", (70, 140, 70))
    canvas_dark = lib.material("Fabric", (52, 108, 54))
    strap = lib.material("Fabric", (60, 50, 44))
    roll = lib.material("Fabric", (200, 70, 60))
    brass = lib.material("Metal", (220, 180, 70))
    lib.box("body", (2.3, 1.3, 2.6), (0, 0, 1.3), mat=canvas, bevel=0.3)
    lib.box("lid", (2.36, 1.4, 0.5), (0, 0.04, 2.55), mat=canvas_dark, bevel=0.2)
    lib.box("pocket", (1.6, 0.4, 1.1), (0, 0.78, 0.85), mat=canvas_dark, bevel=0.15)
    lib.box("pocket_flap", (1.66, 0.46, 0.3), (0, 0.8, 1.42), mat=canvas, bevel=0.1)
    for sx in (-1, 1):
        lib.box("side%d" % sx, (0.35, 0.9, 1.0), (sx * 1.25, 0.05, 0.9), mat=canvas_dark, bevel=0.12)
        lib.box("shoulder%d" % sx, (0.38, 0.22, 2.0), (sx * 0.6, -0.72, 1.4), mat=strap, bevel=0.08)
        lib.box("buckle%d" % sx, (0.26, 0.1, 0.2), (sx * 0.5, 0.82, 1.35), mat=brass)
    lib.cyl("bedroll", 0.42, 2.6, (0, 0, 3.15), rot=(0, 90, 0), mat=roll, verts=12, bevel=0.06)
    for sx in (-1, 1):
        lib.box("tie%d" % sx, (0.14, 0.92, 0.92), (sx * 0.7, 0, 3.15), mat=strap)
