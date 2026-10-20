"""Birch (toy): a slim white trunk with dark bark dashes and a light, airy canopy of small lumps stacked high.
Replaces the game's "birch"."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _nature as nat  # noqa: E402

NAME = "Birch"
HEIGHT = 4.8
BUDGET = 4000
TEX = 1024


def dashes(c):
    """Short dark horizontal dashes scattered up the trunk."""
    a = math.atan2(c.y, c.x)
    band = 0.05 - abs(((c.z * 3.3 + 0.25 * math.sin(a * 3)) % 1.0) - 0.5)
    window = math.sin(a * 2 + c.z * 7.0) - 0.35
    return min(band, window)


def build(k):
    coll = k.new_scene(NAME)
    segs = [((0, 0, -0.1), (0.04, 0.0, 1.8), 0.16), ((0.04, 0.0, 1.8), (-0.03, 0.02, 3.4), 0.13),
            ((0.02, 0, 2.4), (0.45, 0.05, 3.1), 0.06)]
    roots = [((0, 0, 0.3), (0.32 * math.cos(a), 0.32 * math.sin(a), 0.02), 0.07)
             for a in (0.4, 2.5, 4.4)]
    els = [k.capsule(a, b, r) for a, b, r in segs + roots]
    trunk = k.blob(f"{NAME}_Trunk", coll, els, resolution=0.025)
    k.trim(trunk, (0, 0, 0), (0, 0, -1), cap=True)
    k.sdf_attr(trunk, "dash", dashes)
    k.sdf_attr(trunk, "base", lambda c: 0.35 - c.z + 0.08 * math.sin(math.atan2(c.y, c.x) * 4))
    k.set_mats(trunk, k.region_mat(f"{NAME}_TrunkMat", "#f1efe6", [("dash", "#2b2a28", 0.8), ("base", "#6b5a48", 0.9)],
                                   rough=0.7, coat=0.05))
    lumps = [((0.0, 0.0, 3.4), 0.55), ((0.05, 0.05, 4.35), 0.42)]
    for ring, (z, rad, n, r) in enumerate(((2.65, 0.6, 5, 0.42), (3.25, 0.8, 6, 0.48), (3.85, 0.6, 5, 0.44))):
        for i in range(n):
            a = 2 * math.pi * i / n + ring * 0.6
            lumps.append(((math.cos(a) * rad, math.sin(a) * rad, z + 0.1 * math.sin(i * 2.1)), r))
    nat.canopy(k, f"{NAME}_Canopy", coll, lumps, "#76b84a", "#9fd25f", "#56933a", leaves=(20, 0.32, 0.1), seed=5,
               res=0.035)
    return coll
