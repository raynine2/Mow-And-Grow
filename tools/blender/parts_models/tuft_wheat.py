"""Wheat clump, low-part version (~6.3 tall): five golden stalks fanning out of the ground, each carrying a chunky
grain ear (a fat golden block with a darker band), and one long green-gold leaf at the base. 12 parts."""
import math


def build(lib):
    stalk = lib.material("Grass", (214, 172, 70))
    ear = lib.material("Grass", (238, 196, 84))
    band = lib.material("Grass", (196, 150, 56))
    leaf = lib.material("Grass", (150, 160, 60))
    for i in range(5):
        a = i * 72 + 10
        lean = 6 if i == 0 else 14
        ar, lr = math.radians(a), math.radians(lean)
        ln = 4.6 - (i % 2) * 0.4
        cx, cy, cz = math.sin(ar) * math.sin(lr) * ln / 2, math.cos(ar) * math.sin(lr) * ln / 2, math.cos(lr) * ln / 2
        lib.box("stalk%d" % i, (0.22, 0.22, ln), (cx, cy, cz), rot=(-lean, 0, -a), mat=stalk)
        ex, ey, ez = math.sin(ar) * math.sin(lr) * (ln + 0.8), math.cos(ar) * math.sin(lr) * (ln + 0.8), math.cos(lr) * (ln + 0.8)
        lib.box("ear%d" % i, (0.6, 0.5, 1.6), (ex, ey, ez), rot=(-lean, 0, -a), mat=ear if i % 2 else band)
    lib.box("leaf", (0.5, 0.18, 2.6), (0.7, 0.3, 1.1), rot=(-30, 0, -65), mat=leaf)
