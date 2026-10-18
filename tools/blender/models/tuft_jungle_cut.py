"""Cut Jungle Bush clump (what is left of tuft_jungle), ~1.2 tall, same footprint.

Thick round stems of the big leaves cut off flat with pale "fresh cut" tops round the dark crown, the young leaves,
low leaves and flower stems cut lower, and a couple of chopped leaf pieces and loose pink petals on the ground.
Bottom at z = 0, centred on x = y = 0. The layout comes from tuft_jungle.layout().
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _grasskit as gk  # noqa: E402
import _bosskit as bk  # noqa: E402
import tuft_jungle as full  # noqa: E402

PREVIEW = dict(dist=7.5, height=3.8, target_z=0.4, yaw=30)

CUT = (204, 234, 160)


def build(lib):
    dark = lib.material("Grass", full.DARK)
    body = lib.material("Grass", full.BODY)
    petal = lib.material("SmoothPlastic", full.PETAL)
    cut = lib.material("SmoothPlastic", CUT)
    rnd = random.Random(31)
    bk.ellipsoid(lib, "crown", (1.0, 1.0, 0.55), (0, 0, 0), dark, segs=8, rings=2, z_cut=0)
    for i, b in enumerate(full.layout()):
        base = lib.rotated((0, b["r"], 0.0), b["ang"])
        if b["kind"] == "leaf":
            d = 0.62 * b["s"] / 0.82
            gk.stub(lib, "stem%d" % i, base, b["ang"], b["lean"], d, d, rnd.uniform(1.0, 1.2), (dark, body)[i % 2], cut,
                    sides=8, taper=0.9, slant=rnd.uniform(-14, 14))
        elif b["kind"] == "young":
            gk.stub(lib, "young%d" % i, base, b["ang"], b["lean"], 0.5, 0.32, rnd.uniform(0.85, 1.0), dark, cut,
                    taper=0.92, rim=False, slant=rnd.uniform(-10, 10))
        elif b["kind"] == "low":
            gk.stub(lib, "low%d" % i, base, b["ang"], b["lean"], 0.6, 0.28, rnd.uniform(0.5, 0.65), dark, cut,
                    taper=0.92, rim=False)
        else:
            gk.stub(lib, "fstem%d" % i, base, b["ang"], 4, 0.24, 0.24, rnd.uniform(0.6, 0.8), dark, cut, taper=0.95,
                    rim=False)
    # chopped leaf pieces and loose petals on the ground
    for i, a in enumerate((70, 250)):
        loc = lib.rotated((0, rnd.uniform(2.0, 2.4), 0), a)
        gk.clipping(lib, "leafbit%d" % i, loc, a + rnd.uniform(60, 120), 1.4, 0.95, body, curl=24, t=0.14,
                    tip=("edge", "flat")[i])
    for i, a in enumerate((160, 330)):
        x, y, _ = lib.rotated((0, rnd.uniform(1.6, 2.2), 0), a)
        lib.box("petal%d" % i, (0.55, 0.1, 0.85), (x, y, 0.05), rot=(90, 0, rnd.uniform(0, 180)), mat=petal, taper=(0.45, 1))
