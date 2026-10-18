"""Brown backpack with a rolled bedroll on top and leather straps (like Chop A Forest's backpack)."""
VIEW = dict(yaw=25, pitch=10, zoom=1.0)

def build(lib):
    bag = lib.material("Fabric", (118, 84, 60))
    leather = lib.material("SmoothPlastic", (150, 88, 48))
    buckle = lib.material("SmoothPlastic", (230, 180, 60))
    roll = lib.material("SmoothPlastic", (238, 234, 225))
    lib.box("body", (5, 3, 6), (0, 0, 3), mat=bag, bevel=0.5)
    lib.box("pocket", (3.6, 1.2, 2.6), (0, 1.8, 1.8), mat=leather, bevel=0.35)
    lib.box("flap", (5.2, 3.2, 1.0), (0, 0, 6.2), mat=leather, bevel=0.35)
    lib.cyl("roll", 1.2, 5.6, (0, 0, 7.6), rot=(0, 90, 0), mat=roll, verts=16, bevel=0.1)
    for x in (-1.4, 1.4):
        lib.box("strap%d" % (x > 0), (0.6, 3.5, 3.4), (x, 0.05, 6.4), mat=leather, bevel=0.1)
        lib.box("buckle%d" % (x > 0), (0.9, 0.3, 0.8), (x, 1.75, 5.2), mat=buckle, bevel=0.08)
    lib.box("pocketbuckle", (0.9, 0.3, 0.8), (0, 2.45, 2.4), mat=buckle, bevel=0.08)
