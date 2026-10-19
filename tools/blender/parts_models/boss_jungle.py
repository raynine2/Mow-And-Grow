"""Jungle Titan, low-part version (~22 tall): a hulking plant golem built from chunky blocks. Stumpy bark legs with root
toes, a broad hunched torso patched with moss and wrapped in a vine, leafy shoulder domes with fans of broad jungle
leaves and orange flowers, long arms ending in heavy bark fists, and a squat head between the shoulders with a heavy
brow, two glowing amber eyes and a mouth of wooden fangs on the front (+Y), crowned with tall jungle leaves. About 50 parts."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _facekit as fk  # noqa: E402


def build(lib):
    bark = lib.material("Wood", (96, 66, 44))
    bark_d = lib.material("Wood", (78, 52, 36))
    body = lib.material("Grass", (40, 104, 46))
    moss = lib.material("Grass", (96, 150, 70))
    leaf = lib.material("Grass", (30, 124, 50))
    leaf_l = lib.material("Grass", (60, 150, 64))
    flower = lib.material("SmoothPlastic", (255, 140, 40))
    amber = lib.material("Neon", (255, 180, 40))
    dark = lib.material("SmoothPlastic", (30, 24, 20))
    fang = lib.material("Wood", (210, 180, 130))
    for sx in (-1, 1):
        lib.box("leg%d" % sx, (3.0, 3.0, 6.0), (sx * 2.4, 0, 3.0), mat=bark)
        for i, a in enumerate((-30, 30)):
            lib.wedge("toe%d_%d" % (sx, i), (1.2, 2.2, 1.2), (sx * 2.4 + math.sin(math.radians(a)) * 1.2, 2.0, 0.6), rot=(0, 0, 180 + a), mat=bark_d)
    lib.box("torso", (9.0, 6.0, 8.0), (0, -0.3, 10.0), rot=(8, 0, 0), mat=body)
    for i, (x, z) in enumerate([(-2.6, 11.6), (2.8, 8.6), (0.4, 13.4)]):
        lib.box("moss%d" % i, (2.6, 0.5, 2.0), (x, 2.75, z), rot=(8, 0, i * 20), mat=moss)
    lib.box("vine", (9.4, 6.4, 0.7), (0, -0.3, 8.6), rot=(8, 0, 6), mat=leaf_l)
    for sx in (-1, 1):
        lib.sphere("shoulder%d" % sx, 2.6, (sx * 5.4, -0.3, 13.4), mat=moss)
        for i in range(3):
            a = -40 + i * 40
            lib.box("fan%d_%d" % (sx, i), (1.8, 0.3, 4.0), (sx * (5.6 + math.sin(math.radians(a)) * 1.4), -0.8, 15.8), rot=(0, sx * a, 0), mat=leaf if i % 2 else leaf_l)
        lib.sphere("flower%d" % sx, 0.6, (sx * 4.6, 1.6, 15.2), mat=flower)
        lib.box("upperarm%d" % sx, (2.2, 2.2, 5.4), (sx * 6.6, 0.2, 9.6), rot=(0, sx * 10, 0), mat=body)
        lib.box("forearm%d" % sx, (2.0, 2.0, 4.6), (sx * 7.2, 0.6, 5.2), mat=bark)
        lib.box("fist%d" % sx, (3.0, 3.0, 2.6), (sx * 7.3, 0.8, 2.0), mat=bark_d)
    hx, hy, hz = 0, 0.8, 16.4
    lib.box("head", (5.0, 4.4, 3.8), (hx, hy, hz), mat=bark)
    lib.box("brow", (5.4, 1.2, 1.0), (hx, hy + 2.2, hz + 1.0), rot=(10, 0, 0), mat=bark_d)
    for sx in (-1, 1):
        lib.box("eye%d" % sx, (1.1, 0.3, 0.7), (hx + sx * 1.2, hy + 2.25, hz + 0.25), mat=amber)
    lib.box("mouth", (3.4, 0.3, 1.0), (hx, hy + 2.25, hz - 1.0), mat=dark)
    for i in range(4):
        lib.wedge("fang%d" % i, (0.55, 0.3, 0.6), (hx - 1.2 + i * 0.8, hy + 2.45, hz - 0.75), rot=(180, 0, 0), mat=fang)
    for i in range(5):
        a = -50 + i * 25
        lib.box("crown%d" % i, (1.4, 0.3, 4.6), (hx + math.sin(math.radians(a)) * 1.6, hy - 0.4, hz + 3.6), rot=(0, a, 0), mat=leaf if i % 2 else leaf_l)
