"""Rock (toy): a rounded grey boulder of fused lumps with a mossy cap and two pebbles. Replaces "rock"."""
import math

NAME = "Rock"
HEIGHT = 2.4
BUDGET = 1500
TEX = 512


def build(k):
    coll = k.new_scene(NAME)
    rock = k.blob(f"{NAME}_Body", coll, [
        dict(co=(0, 0, 0.35), size=(0.85, 0.65, 0.55)),
        dict(co=(0.45, 0.15, 0.25), size=(0.5, 0.45, 0.4)),
        dict(co=(-0.4, -0.2, 0.2), size=(0.45, 0.4, 0.35)),
        dict(co=(0.05, 0.1, 0.75), size=(0.45, 0.4, 0.3)),
    ], resolution=0.03)
    k.trim(rock, (0, 0, 0), (0, 0, -1), cap=True)
    k.sdf_attr(rock, "moss", lambda c: c.z - (0.72 + 0.1 * math.sin(c.x * 6) + 0.08 * math.sin(c.y * 7 + 1)))
    k.sdf_attr(rock, "dark", lambda c: (0.18 + 0.05 * math.sin(c.x * 9)) - c.z)
    k.set_mats(rock, k.region_mat(f"{NAME}_Mat", "#8a8a84", [("dark", "#77776f", 0.9), ("moss", "#6f9a45", 0.9)],
                                  rough=0.85, coat=0.0, bump="pores", bump_scale=9, bump_strength=0.35))
    stone = k.mat(f"{NAME}_Pebble", "#8c8c86", rough=0.8)
    k.sphere(f"{NAME}_Pebble1", coll, (0.95, -0.35, 0.07), 0.13, stone, scale=(1.2, 1, 0.6), segs=16, rings=10)
    k.sphere(f"{NAME}_Pebble2", coll, (-0.85, 0.4, 0.05), 0.09, stone, scale=(1, 1.3, 0.6), segs=16, rings=10)
    return coll
