"""Venus Flytrap (boss 3): a giant carnivorous plant. Two green jaws gape open toward the front, magenta inside,
rimmed with white teeth, a pink tongue lolling out of a dark throat. Two angry eyes on stalks rise behind the upper
jaw. A thick bent stem grows out of a rosette of broad leaves, with two little traps snapping at its feet. Toy
scale; the game scales it up."""
import math

from mathutils import Vector

NAME = "VenusFlytrap"
HEIGHT = 4.6
JAW, JAW_D, RIM, INSIDE = "#4caf3a", "#2f7f28", "#b6d94a", "#d63a6a"
TOOTH, TONGUE, THROAT, STEM, LEAF = "#fffbea", "#ff86a8", "#3a0e1e", "#3f9d32", "#2f8a2a"


def jaw(k, name, coll, center, radii, upper, open_deg, hinge_y, teeth_n=9, tooth_len=0.22):
    """One half of the trap: a half ellipsoid shell, magenta on the cut face, a pale rim band, white teeth
    along the front of the rim pointing at the other jaw. Rotated open about its back hinge."""
    shell = k.quadsphere(name, coll, center, radii, cuts=40)
    if upper:
        k.trim(shell, (0, 0, 0), (0, 0, -1), cap=True)
    else:
        k.trim(shell, (0, 0, 0), (0, 0, 1), cap=True)
    sgn = 1 if upper else -1
    k.sdf_attr(shell, "inside", lambda c: 0.015 - sgn * c.z)
    k.sdf_attr(shell, "rim", lambda c: 0.09 - sgn * c.z)
    k.set_mats(shell, k.region_mat(f"{name}Mat", JAW, [("rim", RIM, 0.45), ("inside", INSIDE, 0.4)],
                                   rough=0.45, coat=0.3))
    parts = [shell]
    tooth = k.mat(f"{NAME}_Tooth", TOOTH, rough=0.3, coat=0.5)
    for i in range(teeth_n):
        a = math.radians(-160 + i * 140 / (teeth_n - 1)) - (0 if upper else math.radians(140 / (teeth_n - 1) / 2))
        x, y = math.cos(a) * radii[0] * 0.92, math.sin(a) * radii[1] * 0.92
        ln = tooth_len * (0.75 + 0.25 * math.sin(i * 2.1) ** 2)
        t = k.sphere(f"{name}T{i}", coll, Vector(center) + Vector((x, y, -sgn * ln * 0.45)), 1, tooth,
                     scale=(radii[0] * 0.07, radii[0] * 0.07, ln * 0.6), segs=12, rings=8)
        parts.append(t)
    k.turn(parts, Vector(center) + Vector((0, hinge_y, 0)), (-sgn * open_deg, 0, 0))
    return parts


def build(k):
    coll = k.new_scene(NAME)
    leaf = k.mat(f"{NAME}_Leaf", LEAF, rough=0.6, coat=0.1)
    leaf_d = k.mat(f"{NAME}_LeafDark", JAW_D, rough=0.6, coat=0.1)
    stem = k.mat(f"{NAME}_Stem", STEM, rough=0.5, coat=0.2)

    # rosette of broad leaves on a dirt patch
    soil = k.blob(f"{NAME}_Soil", coll, [dict(co=(0, 0, 0), size=(0.7, 0.7, 0.14))],
                  k.mat(f"{NAME}_Soil", "#6b4a2e", rough=0.9, bump="pores", bump_scale=30, bump_strength=0.2))
    k.trim(soil, (0, 0, 0), (0, 0, -1), cap=True)
    for i in range(7):
        a = math.radians(i * 360 / 7 + 20)
        k.leaf(f"{NAME}_Leaf{i}", coll, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.1),
               (math.cos(a), math.sin(a), 0.25), 1.2, 0.36, leaf if i % 2 else leaf_d, curl=0.2, fold=0.12)

    # bent stem rising to the back of the jaws
    k.tube(f"{NAME}_Stem", coll, [(0, 0.1, 0.05), (0.08, 0.25, 0.9), (-0.05, 0.3, 1.7), (0, 0.45, 2.45)],
           [0.22, 0.2, 0.19, 0.2], stem)
    k.leaf(f"{NAME}_StemLeaf", coll, (0.1, 0.25, 1.1), (1, -0.2, 0.6), 0.6, 0.18, leaf, curl=0.25)

    # the trap: lower jaw nearly level, upper jaw thrown open, hinged at the back
    c = Vector((0, -0.15, 2.6))
    jaw(k, f"{NAME}_JawUp", coll, c, (0.95, 0.85, 0.48), True, 34, 0.8)
    jaw(k, f"{NAME}_JawLo", coll, c, (0.95, 0.85, 0.42), False, 8, 0.8)
    k.sphere(f"{NAME}_Throat", coll, c + Vector((0, 0.45, 0.05)), 0.32, k.mat(f"{NAME}_Throat", THROAT, rough=0.6),
             scale=(1.3, 0.8, 0.6))
    k.blob(f"{NAME}_Tongue", coll, [k.capsule(c + Vector((0, 0.3, 0.02)), c + Vector((0, -0.55, 0.0)), 0.13),
                                    k.capsule(c + Vector((0, -0.55, 0.0)), c + Vector((0.05, -0.95, -0.35)), 0.11)],
           k.mat(f"{NAME}_Tongue", TONGUE, rough=0.3, coat=0.6), resolution=0.025)

    # eye stalks rising from behind the upper jaw
    lid = k.mat(f"{NAME}_LidSkin", JAW, rough=0.45, coat=0.3)
    for s in (-1, 1):
        root = Vector((s * 0.3, 0.55, 3.0))
        top = Vector((s * 0.42, 0.35, 3.75))
        k.tube(f"{NAME}_Stalk{'L' if s > 0 else 'R'}", coll, [tuple(root), tuple((root + top) / 2 + Vector((s * 0.05, 0, 0))),
                                                              tuple(top)], [0.09, 0.075, 0.08], stem)
        k.eye(NAME, coll, top + Vector((0, -0.05, 0.12)), 0.22, look=(s * 0.08, -1, -0.15), iris="#c43a20",
              iris_size=0.6, lid=lid, lid_close=0.35, lid_tilt=-24, side=s)

    # two little traps on short stalks at the base, snapping
    for s in (-1, 1):
        base = Vector((s * 0.75, -0.35, 0.1))
        tip = base + Vector((s * 0.15, -0.1, 0.45))
        k.tube(f"{NAME}_Baby{'L' if s > 0 else 'R'}Stalk", coll, [tuple(base), tuple(tip)], [0.07, 0.06], stem)
        bc = tip + Vector((0, -0.12, 0.1))
        jaw(k, f"{NAME}_Baby{'L' if s > 0 else 'R'}Up", coll, bc, (0.26, 0.24, 0.13), True, 30, 0.22, 5, 0.07)
        jaw(k, f"{NAME}_Baby{'L' if s > 0 else 'R'}Lo", coll, bc, (0.26, 0.24, 0.12), False, 10, 0.22, 5, 0.07)
    return coll
