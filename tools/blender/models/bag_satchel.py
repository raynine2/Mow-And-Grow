"""Bag tier 1, the Grass Satchel: a small brown leather shoulder bag with a rounded flap, a brass buckle and a strap
loop. About 2 x 1 x 1.8 studs, standing on z = 0, front +Y."""
PREVIEW = dict(dist=6, height=2.2, target_z=0.9, yaw=30)


def build(lib):
    leather = lib.material("Fabric", (150, 92, 52))
    leather_dark = lib.material("Fabric", (112, 66, 38))
    brass = lib.material("Metal", (220, 180, 70))
    lib.box("body", (2.0, 1.0, 1.5), (0, 0, 0.75), mat=leather, bevel=0.22)
    lib.box("flap", (2.06, 0.25, 1.0), (0, 0.48, 1.12), rot=(6, 0, 0), mat=leather_dark, bevel=0.12, taper=(1, 1))
    lib.box("flap_top", (2.06, 1.06, 0.2), (0, 0.0, 1.52), mat=leather_dark, bevel=0.08)
    lib.box("buckle", (0.36, 0.12, 0.3), (0, 0.66, 0.78), mat=brass, bevel=0.04)
    lib.box("strap", (0.26, 0.2, 1.4), (-0.9, 0, 2.05), rot=(0, 28, 0), mat=leather_dark, bevel=0.04)
    lib.box("strap2", (0.26, 0.2, 1.4), (0.9, 0, 2.05), rot=(0, -28, 0), mat=leather_dark, bevel=0.04)
    lib.box("strap_top", (1.2, 0.2, 0.26), (0, 0, 2.62), mat=leather_dark, bevel=0.04)
