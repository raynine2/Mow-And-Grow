"""Reeds clump (Swamp Reeds), ~8 tall, footprint radius ~2.6: marsh reeds and cattails on a little mud mound.

Eleven long chunky reed blades rise from a low mud mound in two swamp greens, bending over near their pale tips,
with a few short blades splayed at the foot, and four cattails: straight stems carrying fat rounded brown velvet heads with a
thin spike on top. Bottom at z = 0, centred on x = y = 0, no ground tile. `layout()` is shared with tuft_reeds_cut.
"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _grasskit as gk  # noqa: E402
import _bosskit as bk  # noqa: E402

PREVIEW = dict(dist=16, height=7.5, target_z=3.6, yaw=30)

MUD, BODY1, BODY2, TIP, CATTAIL = (94, 70, 46), (64, 138, 88), (84, 158, 102), (156, 204, 126), (116, 66, 34)
MOUND = (1.55, 1.55, 0.6)


def layout():
    rnd = random.Random(13)
    out = []
    for ang, r in gk.ring_positions(rnd, 11, 0.2, 0.75, phase=0, jitter=14):
        h = rnd.uniform(5.6, 7.4)
        l0 = rnd.uniform(5, 9) + r * 7
        out.append(dict(kind="reed", ang=ang, r=r, h=h, w=rnd.uniform(0.5, 0.6), l0=l0, body=len(out) % 2))
    for ang, r in gk.ring_positions(rnd, 5, 0.9, 1.15, phase=30, jitter=18):
        out.append(dict(kind="low", ang=ang, r=r, h=rnd.uniform(2.0, 2.5), w=0.56, l0=rnd.uniform(22, 28), body=len(out) % 2))
    for ang, r in gk.ring_positions(rnd, 4, 0.35, 0.7, phase=50, jitter=20):
        out.append(dict(kind="cattail", ang=ang, r=r, h=rnd.uniform(4.6, 6.0), w=0.2, l0=rnd.uniform(9, 15), body=1))
    return out


def build(lib):
    mud = lib.material("Mud", MUD)
    bodies = [lib.material("Grass", BODY1), lib.material("Grass", BODY2)]
    tip = lib.material("Grass", TIP)
    brown = lib.material("Fabric", CATTAIL)
    mats = [bodies[0], bodies[1], tip]
    bk.ellipsoid(lib, "mound", MOUND, (0, 0, 0), mud, segs=10, rings=3, z_cut=0)
    for i, b in enumerate(layout()):
        base = lib.rotated((0, b["r"], 0.1), b["ang"])
        h, l0, w = b["h"], b["l0"], b["w"]
        if b["kind"] == "reed":
            segs = [(h * 0.42, l0, w * 1.05, 0.24, b["body"]), (h * 0.3, l0 + 7, w, 0.22, b["body"]),
                    (h * 0.16, l0 + 20, w * 0.8, 0.2, b["body"]), (h * 0.14, l0 + 40, w * 0.16, 0.1, 2)]
            gk.blade(lib, "reed%d" % i, base, b["ang"], w, 0.24, segs, mats, twist=(i * 29 % 50) - 25, tip="edge")
        elif b["kind"] == "low":
            segs = [(h * 0.4, l0, w, 0.2, b["body"]), (h * 0.35, l0 + 18, w * 0.85, 0.18, b["body"]),
                    (h * 0.25, l0 + 40, w * 0.15, 0.1, 2)]
            gk.blade(lib, "low%d" % i, base, b["ang"], w, 0.2, segs, mats, twist=20, tip="edge")
        else:
            info = gk.blade(lib, "stem%d" % i, base, b["ang"], 0.2, 0.2, [(h, l0, 0.17, 0.17, 1)], mats, tip="open")
            d, top = info["dir"], info["tip"]
            hl = 1.7
            head = gk.capsule(lib, "cattail%d" % i, 0.4, hl, brown, verts=8)
            gk.oriented(head, top + d * (hl / 2 - 0.15), d)
            bk.cone(lib, "spike%d" % i, top + d * (hl - 0.3), top + d * (hl + 0.7), 0.08, bodies[1], verts=3)
