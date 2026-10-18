"""Tree stump: what's left of an oak after the chop. A short square bark block (4 wide x 2 tall) with sloped root
flares and flat roots, and a light tan cut face on top with darker growth rings, like Chop A Forest's stumps."""
import random

PREVIEW = dict(dist=14, height=7, target_z=0.8)

def build(lib):
    rnd = random.Random(3)
    bark = lib.material("Wood", (122, 70, 48))
    bark_dark = lib.material("Wood", (106, 60, 42))
    cut = lib.material("WoodPlanks", (222, 184, 128))
    ring = lib.material("WoodPlanks", (196, 150, 96))
    w, h = 4.0, 2.0
    lib.box("stump", (w, w, h), (0, 0, h / 2), mat=bark, bevel=0.15, taper=(0.97, 0.97))
    # cut face: a light slab with a bevelled edge, then a ring and a light heart on top of it
    cw = w * 0.97 - 0.3
    lib.box("cut", (cw, cw, 0.2), (0, 0, h + 0.02), mat=cut, bevel=0.08)
    lib.cyl("ring", cw * 0.36, 0.08, (0.1, -0.05, h + 0.14), mat=ring, verts=12)
    lib.cyl("heart", cw * 0.24, 0.1, (0.1, -0.05, h + 0.16), mat=cut, verts=10)
    lib.cyl("pith", cw * 0.07, 0.12, (0.12, -0.04, h + 0.18), mat=ring, verts=6)
    # root flares + flat roots, same recipe as the oak, scaled down
    for i, ang in enumerate((0, 90, 180, 270)):
        a = ang + rnd.uniform(-20, 20)
        lib.wedge("buttress%d" % i, (w * 0.45, 1.5, 1.2), lib.rotated((0, w * 0.5 + 0.7, 0.6), a), rot=(0, 0, a), mat=bark, bevel=0.1)
        reach = rnd.uniform(1.4, 2.1)
        lib.box("root%d" % i, (w * 0.38, reach, 0.5), lib.rotated((rnd.uniform(-0.3, 0.3), w * 0.5 + 1.3 + reach / 2, 0.23), a),
                rot=(-3, 0, a), mat=bark_dark, bevel=0.09, taper=(0.75, 1))
