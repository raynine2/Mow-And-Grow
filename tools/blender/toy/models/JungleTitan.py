"""Jungle Titan (boss 5): a hulking plant golem. A broad, hunched bark body capped with thick green moss, a vine
wrapped round its belly, stumpy bark legs with root toes, long gorilla arms ending in heavy bark fists, leafy
shoulders with fans of big jungle leaves and orange flowers, and a squat head sunk between the shoulders with a
heavy brow, glowing amber eyes, a mouth of wooden fangs and a crown of tall jungle leaves. Toy scale."""
import math
import random

from mathutils import Vector

NAME = "JungleTitan"
HEIGHT = 4.6
BARK, BARK_L, MOSS, MOSS_L = "#6b4a2e", "#8a6440", "#3f8f3a", "#5aa848"
LEAF, LEAF_D, PETAL, CENTRE = "#2f8a2a", "#22701f", "#ff8a1c", "#ffd23a"
MOUTH, FANG, GLOW, VINE = "#2a160c", "#e9d9a8", "#ffb030", "#4f9a3a"

BODY_C = Vector((0.0, 0.05, 2.2))
HEAD_C = Vector((0.0, -0.45, 3.05))


def moss_cap(c):
    """Moss over the top and shoulders of the body, with a wavy lower edge (body space = world)."""
    edge = 2.55 + 0.12 * math.sin(c.x * 5.0) + 0.08 * math.sin(c.y * 7.0 + 1.0)
    return c.z - edge


def bark_grooves(c):
    """Wavy vertical bark grooves (world space): > 0 inside a groove."""
    a = math.atan2(c.y, c.x - (0.6 if c.x > 0.9 else -0.6 if c.x < -0.9 else 0.0))
    return 0.22 - abs(math.sin(a * 7 + c.z * 1.3 + 0.5 * math.sin(c.z * 5.0)))


def mouth(c):
    if c.y > -0.15:
        return -1.0
    return 1.0 - ((c.x / 0.3) ** 4 + ((c.z + 0.17) / 0.1) ** 2)


def fangs(c):
    m = mouth(c)
    if m < 0:
        return -1.0
    ph = ((c.x + 0.3) % 0.12) / 0.12
    tri = 1 - abs(ph - 0.5) * 2
    upper = 0.12 * tri - (-0.07 - c.z)
    ph2 = ((c.x + 0.36) % 0.12) / 0.12
    lower = 0.09 * (1 - abs(ph2 - 0.5) * 2) - (c.z + 0.27)
    return min(m, max(upper, lower))


def flower(k, name, coll, centre, normal, size, petal_m, centre_m):
    n = Vector(normal).normalized()
    t1 = n.cross(Vector((0, 0, 1))).normalized() if abs(n.z) < 0.9 else Vector((1, 0, 0))
    t2 = n.cross(t1)
    for i in range(6):
        a = 2 * math.pi * i / 6
        d = t1 * math.cos(a) + t2 * math.sin(a) + n * 0.25
        k.leaf(f"{name}P{i}", coll, Vector(centre), d, size, size * 0.4, petal_m, curl=0.15, fold=0.1, up=tuple(n))
    k.sphere(f"{name}C", coll, Vector(centre) + n * 0.03, size * 0.3, centre_m, segs=16, rings=10)


def build(k):
    rnd = random.Random(5)
    coll = k.new_scene(NAME)
    bark = k.mat(f"{NAME}_Bark", BARK, rough=0.85, bump="fabric", bump_scale=18, bump_strength=0.35)
    bark_l = k.mat(f"{NAME}_BarkLight", BARK_L, rough=0.8, bump="fabric", bump_scale=22, bump_strength=0.3)
    leaf = k.mat(f"{NAME}_Leaf", LEAF, rough=0.65)
    leaf_d = k.mat(f"{NAME}_LeafDark", LEAF_D, rough=0.65)
    petal = k.mat(f"{NAME}_Petal", PETAL, rough=0.45, coat=0.2)
    centre = k.mat(f"{NAME}_Centre", CENTRE, rough=0.5)
    vine = k.mat(f"{NAME}_Vine", VINE, rough=0.5, coat=0.2)

    # body: a broad hunched torso fused with a belly and two shoulder humps; moss painted over the top
    body = k.blob(f"{NAME}_Body", coll, [
        dict(co=tuple(BODY_C), size=(1.0, 0.72, 0.85)),
        dict(co=tuple(BODY_C + Vector((0, -0.2, -0.45))), size=(0.75, 0.6, 0.55)),
        dict(co=tuple(BODY_C + Vector((-0.85, 0.05, 0.45))), size=(0.55, 0.5, 0.45)),
        dict(co=tuple(BODY_C + Vector((0.85, 0.05, 0.45))), size=(0.55, 0.5, 0.45)),
        dict(co=tuple(BODY_C + Vector((0, 0.3, 0.55))), size=(0.7, 0.45, 0.4)),
    ], resolution=0.035)
    k.sdf_attr(body, "bark", bark_grooves)
    k.sdf_attr(body, "moss", moss_cap)
    k.set_mats(body, k.region_mat(f"{NAME}_Body", BARK_L, [("bark", BARK, 0.9), ("moss", MOSS, 0.9)],
                                  rough=0.85, coat=0.0))
    limb = k.region_mat(f"{NAME}_Limb", BARK_L, [("bark", BARK, 0.9)], rough=0.85, coat=0.0)

    # vine wrapped round the belly
    pts = []
    for i in range(13):
        t = i / 12
        a = t * 2 * math.pi * 1.1 + 0.4
        pts.append((math.cos(a) * 1.02, -0.08 + math.sin(a) * 0.86, 1.5 + t * 0.6))
    k.tube(f"{NAME}_BellyVine", coll, pts, [0.06] * len(pts), vine)
    for i in (3, 7, 10):
        p = Vector(pts[i])
        k.leaf(f"{NAME}_VineLeaf{i}", coll, p, Vector((p.x, p.y, 0.6)), 0.3, 0.1, leaf, curl=0.2)

    # stumpy legs with root toes
    for s in (-1, 1):
        hip = Vector((s * 0.5, 0.1, 1.45))
        foot = Vector((s * 0.6, 0.0, 0.3))
        k.blob(f"{NAME}_Leg{'L' if s > 0 else 'R'}", coll, [k.capsule(hip, foot, 0.32),
                                                             dict(co=(s * 0.6, -0.08, 0.18), size=(0.38, 0.45, 0.2))],
               resolution=0.03)
        legobj = coll.objects[f"{NAME}_Leg{'L' if s > 0 else 'R'}"]
        k.sdf_attr(legobj, "bark", bark_grooves)
        k.set_mats(legobj, limb)
        for j, a in enumerate((-60, -90, -120)):
            r = math.radians(a)
            toe0 = Vector((s * 0.6 + math.cos(r) * 0.2, -0.08 + math.sin(r) * 0.3, 0.1))
            k.tube(f"{NAME}_Toe{'L' if s > 0 else 'R'}{j}", coll,
                   [tuple(toe0), tuple(toe0 + Vector((math.cos(r) * 0.22, math.sin(r) * 0.22, -0.07)))],
                   [0.09, 0.04], bark)

    # long arms to heavy fists near the ground
    for s in (-1, 1):
        sh = Vector((s * 1.15, 0.0, 2.6))
        el = Vector((s * 1.55, -0.15, 1.75))
        wr = Vector((s * 1.55, -0.3, 0.95))
        k.blob(f"{NAME}_Arm{'L' if s > 0 else 'R'}", coll, [k.capsule(sh, el, 0.3), k.capsule(el, wr, 0.26),
                                                             dict(co=tuple(wr + Vector((0, -0.05, -0.3))),
                                                                  size=(0.36, 0.36, 0.34))], resolution=0.03)
        armobj = coll.objects[f"{NAME}_Arm{'L' if s > 0 else 'R'}"]
        k.sdf_attr(armobj, "bark", bark_grooves)
        k.set_mats(armobj, limb)
        for j in range(3):
            kn = wr + Vector((s * (j - 1) * 0.15 * -1, -0.38, -0.2))
            k.sphere(f"{NAME}_Knuckle{'L' if s > 0 else 'R'}{j}", coll, kn, 0.11, bark, segs=16, rings=10)
        # shoulder fan of jungle leaves and two orange flowers
        for j in range(5):
            a = math.radians(-50 + j * 25)
            d = Vector((s * (0.35 + 0.6 * math.cos(a)), 0.35, 0.8 + 0.5 * math.sin(a)))
            k.leaf(f"{NAME}_Shoulder{'L' if s > 0 else 'R'}{j}", coll, sh + Vector((0, 0.15, 0.2)), d,
                   rnd.uniform(0.95, 1.2), 0.24, leaf if j % 2 else leaf_d, curl=-0.25, fold=0.12)
        flower(k, f"{NAME}_Flower{'L' if s > 0 else 'R'}", coll, sh + Vector((s * 0.05, -0.35, 0.3)),
               (s * 0.3, -1, 0.6), 0.2, petal, centre)

    # squat head between the shoulders
    head = k.quadsphere(f"{NAME}_Head", coll, HEAD_C, (0.58, 0.48, 0.46), cuts=48)
    k.push(head, (0, -0.4, 0.15), 0.3, 0.08)                    # brow ridge
    k.subdivide(head, 1)
    k.apply_modifiers(head)
    k.sdf_attr(head, "mouth", mouth)
    k.sdf_attr(head, "fangs", fangs)
    k.set_mats(head, k.region_mat(f"{NAME}_Head", BARK_L, [("mouth", MOUTH, 0.7), ("fangs", FANG, 0.5)],
                                  rough=0.8, coat=0.0))
    k.blob(f"{NAME}_Brow", coll, [k.capsule(HEAD_C + Vector((-0.38, -0.46, 0.22)),
                                            HEAD_C + Vector((0, -0.5, 0.12)), 0.09),
                                  k.capsule(HEAD_C + Vector((0, -0.5, 0.12)),
                                            HEAD_C + Vector((0.38, -0.46, 0.22)), 0.09)], bark, resolution=0.02)
    for s in (-1, 1):
        k.eye(NAME, coll, HEAD_C + Vector((s * 0.2, -0.42, 0.05)), 0.12, look=(s * 0.05, -1, 0), iris=GLOW,
              iris_size=0.8, glow=3.0, side=s, white="#24140a")
    for j in range(7):
        t = (j - 3) / 3
        k.leaf(f"{NAME}_Crown{j}", coll, HEAD_C + Vector((t * 0.25, 0.05, 0.3)), (t * 0.6, 0.15, 1),
               1.0 - abs(t) * 0.35, 0.16, leaf if j % 2 else leaf_d, curl=-0.2, fold=0.1, up=(0, -1, 0))
    return coll
