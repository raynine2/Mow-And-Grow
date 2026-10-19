"""Shared bits for the low-part ride-on mowers (parts_models/mower_*.py): wheels, the seat and a hazard-striped deck,
all boxes and cylinders. Mower frame: front +Y, wheels on z = 0, the seat cushion top flat at z = 3 around (0, -1)."""


def wheel(lib, name, x, y, r, w, tyre, hub, hub_r=None):
    """A tyre (cylinder along X) with a coloured hub cap on its outer side."""
    lib.cyl(name, r, w, (x, y, r), rot=(0, 90, 0), mat=tyre, verts=14)
    side = 1 if x >= 0 else -1
    lib.cyl(name + "_hub", hub_r or r * 0.5, 0.12, (x + side * (w / 2 + 0.04), y, r), rot=(0, 90, 0), mat=hub, verts=10)


def seat(lib, cushion, back, y=-1.0, w=2.2):
    """Cushion top at z = 3 around (0, y), with a high back behind it."""
    lib.box("cushion", (w, 2.0, 0.5), (0, y, 2.75), mat=cushion)
    lib.box("seatback", (w, 0.45, 2.0), (0, y - 1.15, 3.85), rot=(-8, 0, 0), mat=back)


def deck(lib, w, d, y, z, body, stripe_a, stripe_b, n=8):
    """A wide flat cutting deck (w x d) centred at (0, y), top at z, with a hazard-striped front lip."""
    lib.box("deck", (w, d, 0.5), (0, y, z - 0.25), mat=body)
    sw = w / n
    for i in range(n):
        lib.box("lip%d" % i, (sw, 0.3, 0.45), (-w / 2 + sw * (i + 0.5), y + d / 2 + 0.15, z - 0.3), mat=stripe_a if i % 2 == 0 else stripe_b)
