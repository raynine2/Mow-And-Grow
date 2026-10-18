"""Cut Lawn Grass clump (the "stump" left after cutting tuft_lawn), ~0.9 tall, same footprint.

A stubble of the same blades, each cut off flat with a pale "fresh cut" top: the centre blades stand tallest, the
outer ring is cut short, with a few clippings (green pieces with lime tips) lying on the
grass around it. Bottom at z = 0, centred on x = y = 0. The blade layout comes from tuft_lawn.layout().
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _grasskit as gk  # noqa: E402
import tuft_lawn as full  # noqa: E402

PREVIEW = dict(dist=7, height=3.6, target_z=0.3, yaw=30)

CUT = (214, 240, 160)


def build(lib):
    bodies = [lib.material("Grass", full.BODY1), lib.material("Grass", full.BODY2)]
    tipm = lib.material("Grass", full.TIP)
    cut = lib.material("SmoothPlastic", CUT)
    rnd = random.Random(4)
    heights = {"centre": (1.0, 1.15), "mid": (0.75, 0.95), "outer": (0.5, 0.62)}
    for i, b in enumerate(full.layout()):
        h = rnd.uniform(*heights[b["kind"]])
        lean = b["segs"][0][1] * 0.8
        gk.stub(lib, "stub%d" % i, lib.rotated((0, b["r"], 0.0), b["ang"]), b["ang"], lean, b["w"] * 0.9, b["t"], h,
                bodies[b["body"]], cut, sides=4, taper=0.95, slant=rnd.uniform(-8, 8),
                rim=b["kind"] != "outer")
    # clippings lying on the grass around the stubble
    for i in range(5):
        a = i * 360 / 5 + rnd.uniform(-20, 20)
        r = rnd.uniform(1.7, 2.5)
        loc = lib.rotated((0, r, 0), a)
        gk.clipping(lib, "clip%d" % i, loc, a + rnd.uniform(40, 140), rnd.uniform(1.0, 1.3), rnd.uniform(0.32, 0.4),
                    (bodies[i % 2], tipm)[i == 2], curl=rnd.uniform(14, 28), tip=("edge", "flat")[i % 2])
