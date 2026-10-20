"""Log (toy): a fallen log with bark grooves, ringed cut ends, a branch nub and a moss patch. Replaces "log"."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _nature as nat  # noqa: E402

NAME = "Log"
HEIGHT = 2.6
BUDGET = 1800
TEX = 512
R = 0.4


def build(k):
    coll = k.new_scene(NAME)
    body = k.blob(f"{NAME}_Body", coll, [k.capsule((-1.25, 0, R), (1.25, 0, R), R),
                                         k.capsule((0.3, 0, R + 0.25), (0.45, -0.1, R + 0.55), 0.09)],
                  resolution=0.03)
    k.trim(body, (1.1, 0, 0), (1, 0, 0), cap=True)
    k.trim(body, (-1.1, 0, 0), (-1, 0, 0), cap=True)
    k.sdf_attr(body, "bark", nat.bark(9, axis="x", centre=(0, 0, R)))
    k.sdf_attr(body, "moss", lambda c: min(c.z - (2 * R - 0.08), 0.45 - abs(c.x + 0.5 + 0.1 * math.sin(c.y * 9))))
    k.set_mats(body, k.region_mat(f"{NAME}_Mat", "#8a5534", [("bark", "#5e3820", 0.95), ("moss", "#6f9a45", 0.9)],
                                  rough=0.85, coat=0.0, bump="fabric", bump_scale=14, bump_strength=0.25))
    for s in (-1, 1):
        end = k.quadsphere(f"{NAME}_End{'A' if s > 0 else 'B'}", coll, (s * 1.1, 0, R), (0.03, R - 0.015, R - 0.015),
                           cuts=36)
        k.sdf_attr(end, "ring", nat.rings((0, 0, 0), axis="x", spacing=0.06))
        k.sdf_attr(end, "rim", lambda c: math.hypot(c.y, c.z) - (R - 0.07))
        k.set_mats(end, k.region_mat(f"{NAME}_EndMat", "#dcb27a", [("ring", "#b98a55", 0.8), ("rim", "#8a5534", 0.9)],
                                     rough=0.8, coat=0.0))
    return coll
