"""Jungle Bush clump (Mega Jungle), ~9 tall, canopy radius ~3.6: a giant tropical grass / fern clump.

Five huge broad leaves (short dark stalk, wide faceted blade with a raised mid-rib) fan up and out of a dark crown and
bend over at their lighter tips, three lower leaves splay round the foot, three young leaves stand nearly upright in the
middle, and two bright pink jungle flowers (five chunky petals round a yellow centre) poke out on their own stems.
Bottom at z = 0, centred on x = y = 0, no ground tile. `layout()` is shared with tuft_jungle_cut.
"""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
from mathutils import Matrix, Vector  # noqa: E402
import _grasskit as gk  # noqa: E402
import _bosskit as bk  # noqa: E402

PREVIEW = dict(dist=16, height=7.0, target_z=4.0, yaw=30)

DARK, BODY, TIP, PETAL, CENTRE = (18, 96, 40), (30, 140, 58), (104, 196, 84), (240, 64, 120), (255, 214, 60)


def layout():
    rnd = random.Random(17)
    out = []
    for ang, r in gk.ring_positions(rnd, 5, 0.3, 0.45, phase=5, jitter=12):          # tall leaves fanning up and out
        out.append(dict(kind="leaf", ang=ang, r=r, s=rnd.uniform(0.78, 0.85), lean=rnd.uniform(8, 13), body=len(out) % 2))
    for ang, r in gk.ring_positions(rnd, 3, 0.55, 0.7, phase=40, jitter=12):         # low leaves splayed round the foot
        out.append(dict(kind="low", ang=ang, r=r, s=rnd.uniform(0.75, 0.82), lean=rnd.uniform(30, 36), body=len(out) % 2))
    for ang, r in gk.ring_positions(rnd, 3, 0.05, 0.2, phase=40, jitter=20):
        out.append(dict(kind="young", ang=ang, r=r, s=rnd.uniform(1.06, 1.12), lean=rnd.uniform(2, 5), body=1))
    for ang, r, h in ((20, 0.75, 6.2), (215, 0.7, 5.0)):
        out.append(dict(kind="flower", ang=ang, r=r, h=h, lean=14))
    return out


def flower(lib, name, centre, facing, petal_m, centre_m, s=1.0):
    """A jungle flower facing `facing`: five chunky tapered petals cupped forward round a fat yellow centre."""
    q = Vector(facing).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    for k in range(5):
        p = lib.box("%s_petal%d" % (name, k), (0.62 * s, 1.0 * s, 0.14 * s), mat=petal_m, taper=None)
        # petal points out along +Y from the centre, tilted forward 30 degrees
        p.matrix_basis = (Matrix.Translation(centre) @ q @ Matrix.Rotation(math.radians(k * 72), 4, "Z")
                          @ Matrix.Rotation(math.radians(30), 4, "X") @ Matrix.Translation((0, 0.55 * s, 0)))
    c = lib.cyl(name + "_centre", 0.3 * s, 0.34 * s, mat=centre_m, verts=6)
    gk.oriented(c, Vector(centre) + Vector(facing).normalized() * 0.14 * s, facing)


def build(lib):
    dark = lib.material("Grass", DARK)
    body = lib.material("Grass", BODY)
    tip = lib.material("Grass", TIP)
    mats = [dark, body, tip]
    bk.ellipsoid(lib, "crown", (1.0, 1.0, 0.6), (0, 0, 0), dark, segs=8, rings=2, z_cut=0)
    petal = lib.material("SmoothPlastic", PETAL)
    centre = lib.material("SmoothPlastic", CENTRE)
    for i, b in enumerate(layout()):
        base = lib.rotated((0, b["r"], 0.0), b["ang"])
        if b["kind"] == "leaf":
            s, l0, m = b["s"], b["lean"], b["body"]
            segs = [(1.0 * s, l0, 0.6, 0.3, 0),               # dark stalk
                    (1.6 * s, l0 + 6, 1.6 * s, 0.3, m),       # blade widens
                    (1.5 * s, l0 + 18, 2.2 * s, 0.28, m),     # widest
                    (1.3 * s, l0 + 36, 2.0 * s, 0.26, m),     # arching out
                    (1.0 * s, l0 + 60, 1.3 * s, 0.22, 2),     # lighter, bending over
                    (0.8 * s, l0 + 88, 0.14, 0.1, 2)]         # point
            gk.blade(lib, "leaf%d" % i, base, b["ang"], 0.5, 0.3, segs, mats, sides=6, twist=(i * 23 % 40) - 20, tip="edge",
                     fold=0.16)
        elif b["kind"] == "low":
            s, l0, m = b["s"], b["lean"], b["body"]
            segs = [(0.6 * s, l0, 0.6, 0.28, 0), (1.3 * s, l0 + 8, 1.7 * s, 0.26, m), (1.1 * s, l0 + 22, 1.6 * s, 0.24, m),
                    (0.8 * s, l0 + 44, 0.14, 0.1, 2)]
            gk.blade(lib, "low%d" % i, base, b["ang"], 0.5, 0.28, segs, mats, sides=6, twist=-25, tip="edge", fold=0.16)
        elif b["kind"] == "young":
            s, l0 = b["s"], b["lean"]
            segs = [(2.0 * s, l0, 0.45, 0.3, 0), (2.0 * s, l0 + 3, 1.2 * s, 0.28, 1), (2.2 * s, l0 + 8, 1.5 * s, 0.26, 1),
                    (1.5 * s, l0 + 18, 0.9 * s, 0.22, 2), (1.0 * s, l0 + 34, 0.12, 0.1, 2)]
            gk.blade(lib, "young%d" % i, base, b["ang"], 0.42, 0.3, segs, mats, sides=6, twist=40, tip="edge", fold=0.12)
        else:
            info = gk.blade(lib, "fstem%d" % i, base, b["ang"], 0.24, 0.24,
                            [(b["h"] * 0.6, 4, 0.22, 0.22, 0), (b["h"] * 0.4, b["lean"] + 14, 0.2, 0.2, 0)], mats, tip="open")
            face = Vector(info["dir"]) + Vector(lib.rotated((0, 1.4, 0), b["ang"]))
            flower(lib, "flower%d" % i, info["tip"] + info["dir"] * 0.1, face, petal, centre, 1.25)
