"""Golf Grass clump (Golf Course), ~3.2 tall, footprint radius ~2.2: a dense, neat, bright clump.

Lots of narrower, straighter blades packed tight in three rings (upright in the middle, fanning out evenly at the
edge) in two bright golf-course greens with a darker base and pale mint tips, so it reads as a tidy manicured
tuft. Two little three-leaf clovers sit at its foot. Bottom at z = 0, centred on x = y = 0, no ground tile.
`layout()` is shared with tuft_golf_cut.
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _grasskit as gk  # noqa: E402

PREVIEW = dict(dist=8, height=3.9, target_z=1.2, yaw=30)

DARK, BODY1, BODY2, TIP, CLOVER = (28, 110, 46), (50, 170, 72), (70, 192, 90), (150, 232, 120), (40, 150, 70)


def layout():
    rnd = random.Random(5)
    out = []
    for ang, r in gk.ring_positions(rnd, 5, 0.1, 0.25, phase=10, jitter=20):     # centre, upright
        s = rnd.uniform(0.95, 1.05)
        out.append(dict(kind="centre", ang=ang, r=r, w=0.78, t=0.2, segs=[(0.5, 3), (1.1 * s, 7), (0.9 * s, 14), (0.75 * s, 26)]))
    for ang, r in gk.ring_positions(rnd, 8, 0.4, 0.55, phase=22, jitter=8):      # middle
        s = rnd.uniform(0.92, 1.05)
        l0 = rnd.uniform(13, 17)
        out.append(dict(kind="mid", ang=ang, r=r, w=0.74, t=0.2, segs=[(0.45, l0), (0.95 * s, l0 + 8), (0.75 * s, l0 + 20), (0.7 * s, l0 + 38)]))
    for ang, r in gk.ring_positions(rnd, 10, 0.75, 0.85, phase=4, jitter=6):     # outer, fanned evenly
        s = rnd.uniform(0.92, 1.06)
        l0 = rnd.uniform(26, 30)
        out.append(dict(kind="outer", ang=ang, r=r, w=0.66, t=0.18, segs=[(0.35, l0), (0.7 * s, l0 + 14), (0.6 * s, l0 + 36)]))
    for i, b in enumerate(out):
        b["body"] = i % 2
    return out


def clover(lib, name, loc, ang, mat, s=1.0):
    """A three-leaf clover lying just above the ground: three round leaves (squashed 6-sided discs) on a short stem."""
    for k in range(3):
        a = ang + k * 120
        c = lib.rotated((0, 0.24 * s, 0), a)
        leaf = lib.cyl("%s_leaf%d" % (name, k), 0.24 * s, 0.08, (loc[0] + c[0], loc[1] + c[1], 0.32 * s), rot=(12, 0, a),
                       mat=mat, verts=6)
        leaf.scale = (0.85, 1.0, 1.0)
    lib.box(name + "_stem", (0.07, 0.07, 0.34 * s), (loc[0], loc[1], 0.15 * s), mat=mat)


def build(lib):
    mats = [lib.material("Grass", DARK), lib.material("Grass", BODY1), lib.material("Grass", BODY2),
            lib.material("Grass", TIP)]
    for i, b in enumerate(layout()):
        L = b["segs"]
        n = len(L)
        segs = []
        for k, (length, lean) in enumerate(L):
            w = b["w"] * (1.06 if k < n - 2 else 0.86 if k == n - 2 else 0.2)
            mi = 0 if k == 0 else 3 if k == n - 1 else 1 + b["body"]
            segs.append((length, lean, w, b["t"] * (1 - 0.1 * k), mi))
        gk.blade(lib, "blade%d" % i, lib.rotated((0, b["r"], 0.0), b["ang"]), b["ang"], b["w"] * 0.9, b["t"], segs, mats,
                 sides=4, twist=(i * 37 % 40) - 20, tip="edge")
    cm = lib.material("SmoothPlastic", CLOVER)
    clover(lib, "cloverA", lib.rotated((0, 1.55, 0), -5), 20, cm, 1.0)
    clover(lib, "cloverB", lib.rotated((0, 1.45, 0), -75), 75, cm, 0.85)
