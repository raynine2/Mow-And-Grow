"""Jungle tree (toy): a tall trunk on wide buttress roots, three tiers of flat dark-green canopy pads, and vines
hanging from the pads. Replaces the game's "jungle_tree"."""
import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import _nature as nat  # noqa: E402

NAME = "JungleTree"
HEIGHT = 5.0
BUDGET = 5500
TEX = 1024


def build(k):
    rnd = random.Random(9)
    coll = k.new_scene(NAME)
    segs = [((0, 0, -0.1), (0.05, 0.03, 2.4), 0.3), ((0.05, 0.03, 2.4), (0.0, 0.05, 4.3), 0.2)]
    roots = []
    for i in range(6):
        a = math.radians(i * 60 + 20)
        roots.append(((math.cos(a) * 0.1, math.sin(a) * 0.1, 1.0), (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.02), 0.11))
    nat.trunk(k, f"{NAME}_Trunk", coll, segs, roots, "#7a5232", "#4e321c", freq=10)
    vine = k.mat(f"{NAME}_Vine", "#3f8a2f", rough=0.6)
    for t, (z, rad, n) in enumerate(((2.7, 1.25, 8), (3.55, 0.95, 6), (4.35, 0.6, 5))):
        lumps = [((0, 0, z), rad * 0.75)]
        for i in range(n):
            a = 2 * math.pi * i / n + t * 0.5
            lumps.append(((math.cos(a) * rad * 0.8, math.sin(a) * rad * 0.8, z + rnd.uniform(-0.05, 0.08)), rad * 0.55))
        nat.canopy(k, f"{NAME}_Pad{t}", coll, lumps, "#2f7d2a", "#4fa83a", "#1f5c1f", seed=t, res=0.04, squash=0.5)
        # broad leaves drooping off the pad's rim
        lm = k.mat(f"{NAME}_PadLeaf{t}", "#2f7d2a" if t % 2 else "#3a8f30", rough=0.6)
        for i in range(9 - t * 2):
            a = 2 * math.pi * i / (9 - t * 2) + t * 0.3
            o = Vector((math.cos(a), math.sin(a), 0))
            k.leaf(f"{NAME}_PadLeaf{t}x{i}", coll, Vector((0, 0, z)) + o * rad * 0.95, o + Vector((0, 0, -0.55)),
                   0.75 - t * 0.12, 0.2, lm, curl=-0.2, fold=0.15)
        for j in range(3 if t < 2 else 1):
            a = rnd.uniform(0, 2 * math.pi)
            top = Vector((math.cos(a) * rad * 0.9, math.sin(a) * rad * 0.9, z - 0.15))
            ln = rnd.uniform(0.6, 1.1)
            k.tube(f"{NAME}_Vine{t}x{j}", coll, [tuple(top), tuple(top + Vector((0.05, -0.04, -ln * 0.5))),
                                                  tuple(top + Vector((-0.03, 0.02, -ln)))], [0.04, 0.035, 0.03], vine)
            k.leaf(f"{NAME}_VineLeaf{t}x{j}", coll, top + Vector((0, 0, -ln * 0.7)), (0.6, -0.4, -0.3), 0.18, 0.07,
                   vine, curl=0.2)
    return coll
