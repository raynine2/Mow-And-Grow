"""Stump (toy): a cut tree stump with root flares, bark grooves and growth rings on its pale top. Replaces "stump"."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _nature as nat  # noqa: E402

NAME = "Stump"
HEIGHT = 2.2
BUDGET = 1800
TEX = 512


def build(k):
    coll = k.new_scene(NAME)
    roots = []
    for i in range(5):
        a = math.radians(i * 72 + 10)
        roots.append(((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.35), (math.cos(a) * 0.85, math.sin(a) * 0.85, 0.03), 0.14))
    body = nat.trunk(k, f"{NAME}_Body", coll, [((0, 0, -0.1), (0, 0, 0.9), 0.48)], roots, "#8a5534", "#5e3820")
    k.trim(body, (0, 0, 0.78), (0, 0, 1), cap=True)
    top = k.quadsphere(f"{NAME}_Top", coll, (0, 0, 0.78), (0.47, 0.47, 0.035), cuts=40)
    k.sdf_attr(top, "ring", nat.rings((0, 0, 0)))
    k.sdf_attr(top, "rim", lambda c: math.hypot(c.x, c.y) - 0.41)
    k.set_mats(top, k.region_mat(f"{NAME}_TopMat", "#dcb27a", [("ring", "#b98a55", 0.8), ("rim", "#8a5534", 0.9)],
                                 rough=0.8, coat=0.0))
    return coll
