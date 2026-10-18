"""Cut Wheat clump (what is left of tuft_wheat), ~0.9 tall, same footprint: golden stubble.

The seven stalks cut off flat with cream "fresh cut" tops, short stubble around them, the leaf bases cut low, and a
few cut straws and loose grains lying on the ground. Bottom at z = 0, centred on x = y = 0. The stalk layout comes
from tuft_wheat.layout().
"""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import bmesh  # noqa: E402
from mathutils import Matrix  # noqa: E402
import _grasskit as gk  # noqa: E402
import tuft_wheat as full  # noqa: E402

PREVIEW = dict(dist=6.5, height=3.3, target_z=0.3, yaw=30)

CUT = (250, 238, 178)
STUBBLE = (230, 184, 70)


def build(lib):
    stalk = lib.material("Grass", STUBBLE)
    head = lib.material("Fabric", full.HEAD1)
    leaf = lib.material("Grass", full.LEAF)
    cut = lib.material("SmoothPlastic", CUT)
    rnd = random.Random(12)
    for i, b in enumerate(full.layout()):
        base = lib.rotated((0, b["r"], 0.0), b["ang"])
        if b["kind"] == "leaf":
            gk.stub(lib, "leafstub%d" % i, base, b["ang"], b["lean"], 0.5, 0.16, rnd.uniform(0.35, 0.5), leaf, cut,
                    taper=0.95, rim=False, slant=rnd.uniform(-10, 10))
        else:
            gk.stub(lib, "stub%d" % i, base, b["ang"], b["lean"] * 0.9, 0.27, 0.27, rnd.uniform(0.7, 0.92), stalk, cut,
                    taper=0.92, slant=rnd.uniform(-14, 14))
    # extra short stubble in between
    spots = gk.ring_positions(rnd, 5, 0.2, 0.4, phase=40, jitter=20) + gk.ring_positions(rnd, 8, 0.9, 1.4, phase=5, jitter=15)
    for i, (ang, r) in enumerate(spots):
        gk.stub(lib, "stubble%d" % i, lib.rotated((0, r, 0.0), ang), ang, rnd.uniform(4, 16), 0.17, 0.17,
                rnd.uniform(0.35, 0.6) if r > 0.6 else rnd.uniform(0.55, 0.75), stalk, cut, taper=0.92, rim=False,
                slant=rnd.uniform(-16, 16))
    # cut straws lying around
    for i, (ang, r) in enumerate(((40, 1.9), (150, 2.1), (255, 1.8))):
        x, y, _ = lib.rotated((0, r, 0), ang)
        lib.box("straw%d" % i, (0.15, rnd.uniform(0.9, 1.2), 0.15), (x, y, 0.075), rot=(0, 0, ang + rnd.uniform(50, 130)),
                mat=stalk)
    # a few loose grains
    bm = bmesh.new()
    for i in range(4):
        ang, r = rnd.uniform(0, 360), rnd.uniform(1.3, 2.2)
        x, y, _ = lib.rotated((0, r, 0), ang)
        full.kernel(bm, Matrix.Translation((x, y, 0.16)) @ Matrix.Rotation(math.radians(80), 4, "X")
                    @ Matrix.Rotation(math.radians(rnd.uniform(0, 180)), 4, "Y"), 0.4, 0.4, 0.62)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    lib._from_bmesh("grains", bm).data.materials.append(head)
