"""Bag tier 3, the Expedition Pack: a tall orange frame pack on an aluminium frame, with a grey top lid, two water
bottles in side pockets, a sleeping pad strapped underneath and a little hanging lantern. About 2.6 x 1.6 x 4.2
studs, front +Y."""
PREVIEW = dict(dist=9, height=3.4, target_z=2.0, yaw=35)


def build(lib):
    nylon = lib.material("Fabric", (240, 130, 40))
    nylon_dark = lib.material("Fabric", (200, 100, 30))
    lid = lib.material("Fabric", (90, 96, 108))
    frame = lib.material("Metal", (200, 205, 215))
    bottle = lib.material("SmoothPlastic", (60, 160, 230))
    pad = lib.material("Fabric", (250, 220, 70))
    glow = lib.material("Neon", (255, 210, 120))
    lib.box("body", (2.3, 1.3, 3.3), (0, 0.05, 2.15), mat=nylon, bevel=0.3)
    lib.box("lid", (2.4, 1.45, 0.6), (0, 0.1, 3.95), mat=lid, bevel=0.22)
    lib.box("front", (1.7, 0.35, 1.6), (0, 0.78, 1.7), mat=nylon_dark, bevel=0.15)
    for sx in (-1, 1):
        lib.box("rail%d" % sx, (0.14, 0.14, 4.4), (sx * 1.05, -0.78, 2.2), mat=frame)
        lib.box("pocket%d" % sx, (0.4, 0.9, 1.0), (sx * 1.3, 0.05, 1.0), mat=nylon_dark, bevel=0.12)
        lib.cyl("bottle%d" % sx, 0.26, 1.1, (sx * 1.38, 0.05, 1.55), mat=bottle, verts=10)
        lib.cyl("cap%d" % sx, 0.18, 0.2, (sx * 1.38, 0.05, 2.18), mat=lid, verts=8)
    for z in (0.5, 4.3):
        lib.box("bar%d" % int(z * 10), (2.24, 0.14, 0.14), (0, -0.78, z), mat=frame)
    lib.cyl("pad", 0.45, 2.7, (0, 0.05, 0.25), rot=(0, 90, 0), mat=pad, verts=12)
    lib.box("lantern", (0.35, 0.35, 0.45), (1.05, 0.75, 2.9), mat=glow)
    lib.box("lantern_top", (0.42, 0.42, 0.12), (1.05, 0.75, 3.17), mat=frame)
