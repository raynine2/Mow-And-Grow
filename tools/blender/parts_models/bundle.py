"""Grass bundle, low-part version (~2.4 x 1.4 x 1.6): a chunky bale of cut grass with darker bristly ends and two
yellow-brown straps with buckle blocks. The bale and ends are Grass, so the game can recolour mutated bundles. 7 parts."""


def build(lib):
    bale = lib.material("Grass", (120, 200, 70))
    ends = lib.material("Grass", (92, 170, 56))
    strap = lib.material("Fabric", (210, 150, 60))
    buckle = lib.material("Metal", (230, 190, 80))
    lib.box("bale", (2.2, 1.4, 1.5), (0, 0, 0.75), mat=bale)
    for i, x in enumerate((-1.2, 1.2)):
        lib.box("end%d" % i, (0.25, 1.2, 1.3), (x, 0, 0.75), mat=ends)
    for i, x in enumerate((-0.55, 0.55)):
        lib.box("strap%d" % i, (0.28, 1.46, 1.56), (x, 0, 0.75), mat=strap)
        lib.box("buckle%d" % i, (0.36, 0.42, 0.14), (x, 0, 1.58), mat=buckle)
