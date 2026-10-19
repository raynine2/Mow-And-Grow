"""Thorn Bush, low-part version (~16 tall): a big round angry bush. A green ball body covered with chunky leaf clumps
in two greens and long cream thorns pointing every way, dotted with red berries, standing on four gnarled root legs
and swinging two thorny bramble arms. Angry face on the front (+Y), in the upper half. About 50 parts."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _facekit as fk  # noqa: E402


def build(lib):
    green = lib.material("Grass", (56, 140, 56))
    green_l = lib.material("Grass", (80, 168, 66))
    thorn = lib.material("SmoothPlastic", (240, 228, 196))
    berry = lib.material("SmoothPlastic", (220, 40, 50))
    bark = lib.material("Wood", (110, 72, 46))
    white = lib.material("SmoothPlastic", (250, 250, 250))
    black = lib.material("SmoothPlastic", (30, 26, 30))
    mouth = lib.material("SmoothPlastic", (90, 24, 30))
    cx, cy, cz = 0, 0, 8.2
    lib.sphere("body", 5.6, (cx, cy, cz), mat=green, subdiv=2)
    for i in range(10):
        a = math.radians(i * 36 + 10)
        el = math.radians(((i * 47) % 100) - 40)
        x, y, z = math.cos(el) * math.sin(a) * 5.4, math.cos(el) * math.cos(a) * 5.4, math.sin(el) * 5.0
        if y > 3.5 and abs(z) < 2.5:
            continue  # keep the face clear
        lib.box("clump%d" % i, (3.0, 3.0, 2.4), (cx + x, cy + y, cz + z), rot=(i * 17, i * 29, i * 41), mat=green_l)
    for i in range(12):
        a = i * 30 + 15
        el = ((i * 37) % 70) - 35
        r_a, r_el = math.radians(a), math.radians(el)
        x, y, z = math.cos(r_el) * math.sin(r_a) * 6.2, math.cos(r_el) * math.cos(r_a) * 6.2, math.sin(r_el) * 5.6
        lib.box("thorn%d" % i, (0.3, 0.3, 2.2), (cx + x, cy + y, cz + z), rot=(90 - el, 0, -a), mat=thorn)
    for i in range(6):
        a = math.radians(i * 60 + 40)
        lib.sphere("berry%d" % i, 0.45, (cx + math.sin(a) * 5.5, cy + math.cos(a) * 5.5, cz - 1.5 + (i % 3)), mat=berry)
    for i in range(4):
        a = i * 90 + 45
        lib.box("root%d" % i, (1.0, 3.6, 1.0), lib.rotated((0, 2.4, 1.6), a), rot=(-35, 0, a), mat=bark)
    for sx in (-1, 1):
        lib.box("arm%d" % sx, (4.5, 0.8, 0.8), (sx * 7.4, 0.5, 9.0), rot=(0, sx * 20, 0), mat=bark)
        lib.box("armthorn%d" % sx, (0.25, 0.25, 1.4), (sx * 8.4, 0.5, 9.9), mat=thorn)
    fk.face(lib, cx, cy + 5.4, cz + 1.6, 1.2, white, black, black, mouth, white)
