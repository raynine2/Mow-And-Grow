"""Lawn Grass clump (Backyard Lawn), ~4.5 tall, footprint radius ~2.6: the "tree" you cut in zone 1.

A big lush clump of thick chunky blades fanning out of a dark-green crown: four near-upright blades in the middle, a
ring of seven taller blades arching outward and a ring of short blades splayed low at the edge. Every blade is a
bevel-free faceted slab (mid-rib) that goes dark green at the base -> two body greens -> a light lime tip, and
twists a little. Bottom at z = 0, centred on x = y = 0, no ground tile. `layout()` is shared with tuft_lawn_cut.
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _grasskit as gk  # noqa: E402
import _bosskit as bk  # noqa: E402

PREVIEW = dict(dist=10, height=4.6, target_z=1.9, yaw=30)

DARK, BODY1, BODY2, TIP = (34, 100, 30), (58, 150, 42), (82, 174, 50), (176, 236, 92)


def layout():
    """The clump's blades: dicts with heading, base radius, widths, segments (length, lean) and body colour index."""
    rnd = random.Random(21)
    out = []
    for ang, r in gk.ring_positions(rnd, 4, 0.15, 0.3, phase=20, jitter=20):     # centre: tall, almost upright
        s = rnd.uniform(0.95, 1.05)
        out.append(dict(kind="centre", ang=ang, r=r, w=1.05, t=0.34, twist=rnd.uniform(-25, 25),
                        segs=[(0.6, 4), (1.65 * s, 7), (1.55 * s, 15), (0.8 * s, 30)], ws=[1.12, 1.08, 0.86, 0.3]))
    for ang, r in gk.ring_positions(rnd, 9, 0.45, 0.6, phase=10):              # middle: arching outward
        s = rnd.uniform(0.9, 1.08)
        l0 = rnd.uniform(13, 18)
        out.append(dict(kind="mid", ang=ang, r=r, w=1.0, t=0.3, twist=rnd.uniform(-30, 30),
                        segs=[(0.55, l0), (0.95 * s, l0 + 7), (0.85 * s, l0 + 20), (0.7 * s, l0 + 38), (0.55 * s, l0 + 58)],
                        ws=[1.08, 1.12, 1.0, 0.76, 0.26]))
    for ang, r in gk.ring_positions(rnd, 8, 0.8, 0.95, phase=22):              # outer: short, splayed low
        s = rnd.uniform(0.9, 1.1)
        l0 = rnd.uniform(30, 38)
        out.append(dict(kind="outer", ang=ang, r=r, w=0.8, t=0.26, twist=rnd.uniform(-20, 20),
                        segs=[(0.4, l0), (0.75 * s, l0 + 18), (0.5 * s, l0 + 42)], ws=[0.86, 0.72, 0.24]))
    for i, b in enumerate(out):
        b["body"] = i % 2
    return out


def build(lib):
    mats = [lib.material("Grass", DARK), lib.material("Grass", BODY1), lib.material("Grass", BODY2),
            lib.material("Grass", TIP)]
    # the crown the blades grow out of
    bk.ellipsoid(lib, "crown", (1.15, 1.15, 0.55), (0, 0, 0), mats[0], segs=9, rings=2, z_cut=0)
    for i, b in enumerate(layout()):
        body = 1 + b["body"]
        L = b["segs"]
        segs = [(L[0][0], L[0][1], b["ws"][0] * b["w"], b["t"], 0)]
        for k in range(1, len(L) - 1):
            segs.append((L[k][0], L[k][1], b["ws"][k] * b["w"], b["t"] * (1 - 0.12 * k), body))
        segs.append((L[-1][0], L[-1][1], b["ws"][-1] * b["w"], 0, 3))
        sides = 6 if b["kind"] != "outer" else 4
        gk.blade(lib, "blade%d" % i, lib.rotated((0, b["r"], 0.0), b["ang"]), b["ang"], b["w"] * 0.85, b["t"],
                 segs, mats, sides=sides, twist=b["twist"], tip="edge")
