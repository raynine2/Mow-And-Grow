"""Cut Reeds clump (what is left of tuft_reeds), ~1.15 tall, same footprint.

The mud mound with the reed blades and cattail stems cut off flat (pale green "fresh cut" tops), the short foot
blades cut low, and a cut cattail head plus a few reed clippings lying in the mud and grass around it. Bottom at
z = 0, centred on x = y = 0. The layout comes from tuft_reeds.layout().
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
from mathutils import Vector  # noqa: E402
import _grasskit as gk  # noqa: E402
import _bosskit as bk  # noqa: E402
import tuft_reeds as full  # noqa: E402

PREVIEW = dict(dist=7, height=3.6, target_z=0.4, yaw=30)

CUT = (206, 236, 170)


def build(lib):
    mud = lib.material("Mud", full.MUD)
    bodies = [lib.material("Grass", full.BODY1), lib.material("Grass", full.BODY2)]
    brown = lib.material("Fabric", full.CATTAIL)
    cut = lib.material("SmoothPlastic", CUT)
    rnd = random.Random(6)
    bk.ellipsoid(lib, "mound", full.MOUND, (0, 0, 0), mud, segs=8, rings=2, z_cut=0)
    for i, b in enumerate(full.layout()):
        base = lib.rotated((0, b["r"], 0.1), b["ang"])
        if b["kind"] == "reed":
            gk.stub(lib, "stub%d" % i, base, b["ang"], b["l0"], b["w"], 0.24, rnd.uniform(0.75, 1.1), bodies[b["body"]],
                    cut, taper=0.95, slant=rnd.uniform(-12, 12), rim=i % 2 == 0)
        elif b["kind"] == "low":
            gk.stub(lib, "lowstub%d" % i, base, b["ang"], b["l0"] * 0.8, b["w"], 0.2, rnd.uniform(0.45, 0.6),
                    bodies[b["body"]], cut, taper=0.95, rim=False)
        else:
            gk.stub(lib, "stemstub%d" % i, base, b["ang"], b["l0"], 0.2, 0.2, rnd.uniform(0.8, 1.0), bodies[1], cut,
                    taper=0.95, rim=False)
    # a cut cattail lying on the ground, and a few reed clippings
    head = gk.capsule(lib, "fallen_cattail", 0.36, 1.5, brown, verts=6)
    p = Vector(lib.rotated((0, 2.0, 0), 25)); p.z = 0.32
    gk.oriented(head, p, Vector(lib.rotated((0, 1, 0.08), 115)))
    for i, a in enumerate((140, 230, 320)):
        loc = lib.rotated((0, rnd.uniform(1.8, 2.3), 0), a + rnd.uniform(-15, 15))
        gk.clipping(lib, "clip%d" % i, loc, a + rnd.uniform(60, 120), rnd.uniform(1.1, 1.4), 0.42, bodies[i % 2],
                    curl=rnd.uniform(14, 26), tip=("edge", "flat")[i % 2])
