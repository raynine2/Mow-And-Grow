"""Cut Golf Grass clump (what is left of tuft_golf), ~0.75 tall, same footprint.

A neat, dense stubble of the same blades cut off flat with pale mint "fresh cut" tops (the middle ones a little
taller), a clover that survived the mower and a few clippings on the grass. Bottom at z = 0, centred on x = y = 0.
The blade layout comes from tuft_golf.layout().
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _grasskit as gk  # noqa: E402
import tuft_golf as full  # noqa: E402

PREVIEW = dict(dist=6.5, height=3.3, target_z=0.3, yaw=30)

CUT = (210, 246, 186)


def build(lib):
    bodies = [lib.material("Grass", full.BODY1), lib.material("Grass", full.BODY2)]
    tipm = lib.material("Grass", full.TIP)
    cut = lib.material("SmoothPlastic", CUT)
    rnd = random.Random(8)
    heights = {"centre": (0.68, 0.78), "mid": (0.55, 0.66), "outer": (0.42, 0.5)}
    for i, b in enumerate(full.layout()):
        h = rnd.uniform(*heights[b["kind"]])
        gk.stub(lib, "stub%d" % i, lib.rotated((0, b["r"], 0.0), b["ang"]), b["ang"], b["segs"][0][1] * 0.8,
                b["w"] * 0.95, b["t"], h, bodies[b["body"]], cut, sides=4, taper=0.97, slant=rnd.uniform(-5, 5),
                rim=b["kind"] == "centre")
    full.clover(lib, "clover", lib.rotated((0, 1.55, 0), -5), 20, lib.material("SmoothPlastic", full.CLOVER), 1.0)
    for i, a in enumerate((60, 170, 270)):
        loc = lib.rotated((0, rnd.uniform(1.6, 2.2), 0), a + rnd.uniform(-15, 15))
        gk.clipping(lib, "clip%d" % i, loc, a + rnd.uniform(50, 130), rnd.uniform(0.8, 1.0), 0.32,
                    (bodies[i % 2], tipm)[i == 1], curl=rnd.uniform(14, 26), tip=("edge", "flat")[i % 2])
