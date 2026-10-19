"""Dandelion King (boss 1): a grumpy yellow dandelion flower with a round face, two fans of strap petals, a little
gold crown whose points end in white seed puffs, a bent green stem with two flexed leaf arms, and a rosette of
toothed dandelion leaves on a dirt mound. Toy scale (about 4.3 studs); the game scales it up."""
import math

from mathutils import Vector

NAME = "DandelionKing"
HEIGHT = 4.4
FACE, PETAL_A, PETAL_B, PETAL_BACK = "#ffd23a", "#ffc414", "#ffe25c", "#f2a419"
STEM, LEAF, LEAF_D, SOIL = "#4caf3a", "#2f8a2a", "#226f20", "#6b4a2e"
MOUTH, TOOTH, BROW, GOLD, PUFF = "#5a1616", "#fffbea", "#6b3a12", "#f4b81c", "#fbfbf6"

HEAD_C = Vector((0.0, 0.0, 2.95))
HEAD_R = (0.78, 0.55, 0.74)


def mouth_z(x):
    """Centre line of the grimace in head space: the corners pull down."""
    return -0.27 - 0.09 * (x / 0.36) ** 2


def mouth(c):
    if c.y > -0.15:
        return -1.0
    return 1.0 - ((c.x / 0.36) ** 4 + ((c.z - mouth_z(c.x)) / 0.13) ** 2)


def teeth(c):
    m = mouth(c)
    if m < 0:
        return -1.0
    top = (c.z - mouth_z(c.x)) - 0.025                          # upper row
    gaps = 0.045 - abs(((c.x + 0.36) % 0.12) - 0.06)            # a gap every 0.12
    upper = min(m, top, gaps)
    fangs = -1.0
    for s in (-1, 1):                                            # two lower fangs pointing up
        dx = abs(c.x - s * 0.19)
        dz = c.z - (mouth_z(c.x) - 0.13)
        fangs = max(fangs, min(m, 0.11 * (1 - dx / 0.055) - dz))
    return max(upper, fangs)


def toothed_leaf(k, name, coll, base, ang, length, width, lift, mat_main, mat_lobe):
    """A dandelion leaf: a long pointed blade with two pairs of backward-pointing side lobes."""
    d = Vector((math.cos(ang), math.sin(ang), lift)).normalized()
    k.leaf(name, coll, base, d, length, width, mat_main, curl=0.18, fold=0.1)
    side = Vector((-math.sin(ang), math.cos(ang), 0))
    for i, t in enumerate((0.38, 0.62)):
        p = Vector(base) + d * (length * t)
        for s in (-1, 1):
            ld = (side * s * 0.85 - d * 0.35 + Vector((0, 0, 0.12))).normalized()
            k.leaf(f"{name}Lobe{i}{'L' if s > 0 else 'R'}", coll, p, ld, length * (0.3 - 0.06 * i),
                   width * 0.55, mat_lobe, curl=0.1, fold=0.06)


def build(k):
    coll = k.new_scene(NAME)
    leaf = k.mat(f"{NAME}_Leaf", LEAF, rough=0.6, coat=0.1)
    leaf_d = k.mat(f"{NAME}_LeafDark", LEAF_D, rough=0.6, coat=0.1)
    stem = k.mat(f"{NAME}_Stem", STEM, rough=0.55, coat=0.15)
    gold = k.mat(f"{NAME}_Gold", GOLD, rough=0.25, coat=0.7)
    puff = k.mat(f"{NAME}_Puff", PUFF, rough=0.9, sheen=0.6, bump="fabric", bump_scale=90, bump_strength=0.25)
    face_m = k.mat(f"{NAME}_FaceSkin", FACE, rough=0.5, coat=0.2)

    # Dirt mound and the leaf rosette on it.
    soil = k.blob(f"{NAME}_Soil", coll, [dict(co=(0, 0, 0.0), size=(0.62, 0.62, 0.16)),
                                         dict(co=(0.25, -0.1, 0.02), size=(0.3, 0.3, 0.1))],
                  k.mat(f"{NAME}_Soil", SOIL, rough=0.9, bump="pores", bump_scale=30, bump_strength=0.2))
    k.trim(soil, (0, 0, 0), (0, 0, -1), cap=True)
    for i in range(7):
        a = math.radians(i * (360 / 7) + 12)
        base = (math.cos(a) * 0.18, math.sin(a) * 0.18, 0.12)
        toothed_leaf(k, f"{NAME}_Leaf{i}", coll, base, a, 1.45 if i % 2 else 1.25, 0.3, 0.3,
                     leaf if i % 2 else leaf_d, leaf)

    # Bent stem with a little collar of sepals under the flower.
    k.tube(f"{NAME}_Stem", coll, [(0, 0.04, 0.05), (0.05, 0.1, 0.8), (-0.04, 0.02, 1.55), (0, 0.06, 2.35)],
           [0.17, 0.155, 0.145, 0.14], stem)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        k.leaf(f"{NAME}_Sepal{i}", coll, (math.cos(a) * 0.1, 0.12 + math.sin(a) * 0.1, 2.3),
               (math.cos(a), math.sin(a) * 0.6 + 0.3, -1.1), 0.42, 0.13, leaf_d, curl=-0.15, fold=0.05)

    # Flexed leaf arms ending in leaf "fists" that point up.
    for s in (-1, 1):
        pts = [(s * 0.08, 0.05, 1.25), (s * 0.5, -0.02, 1.32), (s * 0.85, -0.08, 1.55), (s * 0.95, -0.12, 1.85)]
        k.tube(f"{NAME}_Arm{'L' if s > 0 else 'R'}", coll, pts, [0.075, 0.07, 0.065, 0.06], stem)
        tip = Vector(pts[-1])
        for j, spread in enumerate((-35, 0, 35)):
            r = math.radians(spread)
            d = Vector((math.sin(r) * s * 0.8, -0.15, math.cos(r)))
            k.leaf(f"{NAME}_Hand{'L' if s > 0 else 'R'}{j}", coll, tip - Vector((0, 0, 0.04)), d,
                   0.5 - 0.08 * abs(j - 1), 0.14, leaf, curl=0.2, fold=0.08, up=(0, -1, 0))

    # Head: a flattened ball, cheeks pushed out, the grimace dented in, then crisp face regions.
    head = k.quadsphere(f"{NAME}_Head", coll, HEAD_C, HEAD_R, cuts=56)
    for s in (-1, 1):
        k.push(head, (s * 0.42, -0.45, -0.18), 0.32, 0.05)
    k.push(head, (0, -0.55, -0.3), 0.34, -0.035)
    k.subdivide(head, 1)
    k.apply_modifiers(head)
    k.sdf_attr(head, "mouth", mouth)
    k.sdf_attr(head, "teeth", teeth)
    k.set_mats(head, k.region_mat(f"{NAME}_Head", FACE, [("mouth", MOUTH, 0.6), ("teeth", TOOTH, 0.3)],
                                  rough=0.5, coat=0.2))

    # Eyes with angry lids, and heavy brows slanting down to the middle.
    for s in (-1, 1):
        k.eye(NAME, coll, HEAD_C + Vector((s * 0.26, -0.43, 0.13)), 0.17, look=(s * 0.05, -1, -0.05),
              iris="#2f6b1f", iris_size=0.66, lid=face_m, lid_close=0.36, lid_tilt=-24, side=s)
        k.blob(f"{NAME}_Brow{'L' if s > 0 else 'R'}", coll,
               [k.capsule(HEAD_C + Vector((s * 0.1, -0.56, 0.3)), HEAD_C + Vector((s * 0.42, -0.5, 0.42)), 0.055)],
               k.mat(f"{NAME}_Brow", BROW, rough=0.5, coat=0.2), resolution=0.02)

    # A shaggy dandelion pom-pom: three layers of thin strap rays. The front layer leans towards the viewer and
    # frames the face like a mane, the back layers fan out wider and deeper orange. Open at the top for the crown.
    rays = (  # (count, radius, length, half width, y offset, lean to -Y, colours)
        (30, 0.68, 0.46, 0.065, -0.12, -0.55, (PETAL_A, PETAL_B)),
        (28, 0.66, 0.66, 0.07, 0.08, -0.1, (PETAL_B, PETAL_A)),
        (26, 0.6, 0.74, 0.075, 0.28, 0.35, (PETAL_BACK, PETAL_A)),
    )
    for ring, (n, rad, ln, wd, yoff, lean, cols) in enumerate(rays):
        mats = [k.mat(f"{NAME}_Ray{c[1:]}", c, rough=0.5, coat=0.15) for c in cols]
        for i in range(n):
            a = 2 * math.pi * (i + 0.5 * ring) / n
            if math.cos(a - math.pi / 2) > 0.93 and ring < 2:   # leave the top clear for the crown
                continue
            wob = 0.06 * math.sin(i * 2.7 + ring)
            d = Vector((math.cos(a), lean + wob, math.sin(a))).normalized()
            base = HEAD_C + Vector((math.cos(a) * rad, yoff, math.sin(a) * rad * 0.95))
            k.leaf(f"{NAME}_Ray{ring}x{i}", coll, base, d, ln * (1 + 0.12 * math.sin(i * 1.9)), wd,
                   mats[i % 2], curl=0.08, fold=0.05, up=(0, 1, 0))
    # green bracts curling back over the back of the flower head (a dandelion's tell-tale collar)
    for i in range(11):
        a = 2 * math.pi * i / 11 + 0.2
        base = HEAD_C + Vector((math.cos(a) * 0.18, 0.56, math.sin(a) * 0.18))
        d = Vector((math.cos(a) * 0.7, 0.75, math.sin(a) * 0.7))
        k.leaf(f"{NAME}_Bract{i}", coll, base, d, 0.7, 0.11, leaf_d, curl=-0.3, fold=0.05, up=(0, -1, 0))

    # Crown: a gold band on top of the head, five points, each tipped with a white seed puff.
    top = HEAD_C + Vector((0, 0.05, HEAD_R[2] - 0.08))
    k.torus(f"{NAME}_CrownBand", coll, top, (0.3, 0.26), 0.06, gold)
    for i in range(5):
        a = 2 * math.pi * i / 5 + math.pi / 2
        foot = top + Vector((math.cos(a) * 0.29, math.sin(a) * 0.25, 0.02))
        tip = foot + Vector((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.3))
        k.blob(f"{NAME}_CrownPt{i}", coll, [k.capsule(foot, tip, 0.05)], gold, resolution=0.02)
        k.sphere(f"{NAME}_Puff{i}", coll, tip + Vector((0, 0, 0.07)), 0.095, puff, segs=24, rings=16)

    # A small head tilt towards the viewer.
    head_parts = k.by_prefix(coll, f"{NAME}_Head", f"{NAME}_Eye", f"{NAME}_Iris", f"{NAME}_Pupil",
                             f"{NAME}_Glint", f"{NAME}_Lid", f"{NAME}_Brow", f"{NAME}_Ray", f"{NAME}_Bract", f"{NAME}_Crown",
                             f"{NAME}_Puff")
    k.turn(head_parts, (0, 0, 2.3), (6, 4, -8))
    return coll
