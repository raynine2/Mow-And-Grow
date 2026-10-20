"""Oak (toy): a chunky reddish-brown trunk flaring into root buttresses, two branches, and a big lumpy two-tone
canopy with leaf tips poking out. Replaces the game's "oak"."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _nature as nat  # noqa: E402

NAME = "Oak"
HEIGHT = 4.6
BUDGET = 5000
TEX = 1024
SEED = 3
SCALE = 1.0


def build(k):
    coll = k.new_scene(NAME)
    s = SCALE
    segs = [((0, 0, -0.1), (0.05, 0.02, 1.7 * s), 0.34 * s), ((0.05, 0.02, 1.7 * s), (0.1, 0.0, 2.6 * s), 0.27 * s),
            ((0.05, 0, 1.9 * s), (0.75 * s, 0.15, 2.75 * s), 0.13 * s),
            ((0.0, 0, 2.0 * s), (-0.65 * s, -0.12, 2.7 * s), 0.12 * s)]
    roots = []
    for i in range(5):
        a = math.radians(i * 72 + 15)
        roots.append(((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.5 * s),
                      (math.cos(a) * 0.75 * s, math.sin(a) * 0.75 * s, 0.03), 0.13 * s))
    nat.trunk(k, f"{NAME}_Trunk", coll, segs, roots, "#8a5534", "#5e3820")
    # puffy lobes: a filler inside, a wide lower ring, a smaller upper ring and a crown lobe
    lumps = [((0.05, 0.0, 3.25 * s), 0.75 * s), ((0.08, 0.05, 4.1 * s), 0.52 * s)]
    for i in range(7):
        a = math.radians(i * 360 / 7 + SEED * 20)
        lumps.append(((math.cos(a) * 1.1 * s, math.sin(a) * 1.1 * s, (3.0 + 0.2 * math.sin(i * 2.3)) * s),
                      (0.58 + 0.07 * math.cos(i * 1.7)) * s))
    for i in range(5):
        a = math.radians(i * 72 + 30 + SEED * 10)
        lumps.append(((math.cos(a) * 0.62 * s, math.sin(a) * 0.62 * s, 3.7 * s), 0.55 * s))
    nat.canopy(k, f"{NAME}_Canopy", coll, lumps, "#4f9e3a", "#7cc64f", "#357a2a", leaves=(22, 0.45 * s, 0.14 * s),
               seed=SEED)
    return coll
