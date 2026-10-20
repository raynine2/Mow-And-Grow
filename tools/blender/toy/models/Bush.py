"""Bush (toy): a soft lumpy round bush, sun-lit on top, sprinkled with little white flowers. Replaces "bush"."""
import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import _nature as nat  # noqa: E402

NAME = "Bush"
HEIGHT = 2.4
BUDGET = 2500
TEX = 512


def build(k):
    rnd = random.Random(4)
    coll = k.new_scene(NAME)
    lumps = [((0, 0, 0.5), 0.5)]
    for i in range(7):
        a = math.radians(i * 360 / 7 + 15)
        lumps.append(((math.cos(a) * 0.7, math.sin(a) * 0.62, 0.38 + 0.12 * (i % 2)), 0.38 + 0.05 * math.sin(i)))
    for i in range(3):
        a = math.radians(i * 120 + 40)
        lumps.append(((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.88), 0.36))
    body = nat.canopy(k, f"{NAME}_Body", coll, lumps, "#4a9a38", "#78c44d", "#357a2a", leaves=(12, 0.22, 0.08),
                      seed=2, res=0.035)
    k.trim(body, (0, 0, 0), (0, 0, -1), cap=True)
    petal = k.mat(f"{NAME}_Petal", "#fbf7ee", rough=0.5)
    centre = k.mat(f"{NAME}_Centre", "#f4c22a", rough=0.5)
    for i in range(9):
        a = rnd.uniform(0, 2 * math.pi)
        e = rnd.uniform(0.15, 1.1)
        d = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        p = Vector((0, 0, 0.55)) + Vector((d.x * 0.95, d.y * 0.9, d.z * 0.62))
        k.sphere(f"{NAME}_Flower{i}", coll, p, 0.07, petal, scale=(1, 1, 0.45), segs=12, rings=8)
        k.sphere(f"{NAME}_FlowerC{i}", coll, p + d * 0.03, 0.03, centre, segs=8, rings=6)
    return coll
