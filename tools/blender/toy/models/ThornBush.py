"""Thorn Bush (boss 2): a big round angry bush. A lumpy green ball body shaggy with leaves in two greens, long cream
thorns poking out every way and clusters of glossy red berries, standing on four gnarled root legs and swinging two
thorny bramble arms. Angry face on the front. Toy scale; the game scales it up."""
import math
import random

from mathutils import Vector

NAME = "ThornBush"
HEIGHT = 4.2
BUSH, BUSH_L, LEAF_A, LEAF_B = "#3f9a36", "#58b247", "#2f8a2a", "#6cc04f"
ROOT, THORN, BERRY, MOUTH, TOOTH, BROW = "#6b4428", "#efe2bf", "#d8242c", "#3a1414", "#fffbea", "#3a2614"

C = Vector((0.0, 0.0, 2.15))
R = Vector((1.15, 1.0, 1.05))


def grin_z(x):
    return -0.36 - 0.08 * (x / 0.42) ** 2


def mouth(p):
    c = p - C
    if c.y > -0.5:
        return -1.0
    return 1.0 - ((c.x / 0.42) ** 4 + ((c.z - grin_z(c.x)) / 0.15) ** 2)


def teeth(p):
    m = mouth(p)
    if m < 0:
        return -1.0
    c = p - C
    upper = min((c.z - grin_z(c.x)) - 0.03, 0.045 - abs(((c.x + 0.42) % 0.14) - 0.07))
    lower = (grin_z(c.x) - 0.06) - c.z
    gaps_lo = 0.045 - abs(((c.x + 0.42 + 0.07) % 0.14) - 0.07)
    return min(m, max(upper, min(lower, gaps_lo)))


def surface(d):
    """A point on the body's ellipsoid in direction d, and its outward normal."""
    d = Vector(d).normalized()
    p = Vector((d.x * R.x, d.y * R.y, d.z * R.z))
    n = Vector((p.x / R.x ** 2, p.y / R.y ** 2, p.z / R.z ** 2)).normalized()
    return C + p, n


def fib(n):
    """n directions spread evenly over a sphere."""
    g = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - z * z)
        yield Vector((math.cos(g * i) * r, math.sin(g * i) * r, z))


def face_area(d):
    return d.y < -0.55 and abs(d.x) < 0.75 and -0.75 < d.z < 0.65


def build(k):
    rnd = random.Random(11)
    coll = k.new_scene(NAME)
    root = k.mat(f"{NAME}_Root", ROOT, rough=0.8, bump="fabric", bump_scale=25, bump_strength=0.3)
    leaf_a = k.mat(f"{NAME}_LeafA", LEAF_A, rough=0.6, coat=0.1)
    leaf_b = k.mat(f"{NAME}_LeafB", LEAF_B, rough=0.6, coat=0.1)
    thorn = k.mat(f"{NAME}_Thorn", THORN, rough=0.4, coat=0.4)
    berry = k.mat(f"{NAME}_Berry", BERRY, rough=0.15, coat=1.0)

    # lumpy body: a main ellipsoid plus bumps, face painted on the front
    els = [dict(co=tuple(C), size=tuple(R))]
    for d in fib(14):
        if face_area(d):
            continue
        p, _ = surface(d)
        els.append(dict(co=tuple(C + (p - C) * 0.72), size=(0.42, 0.42, 0.4)))
    body = k.blob(f"{NAME}_Body", coll, els, resolution=0.03)
    k.sdf_attr(body, "mouth", mouth)
    k.sdf_attr(body, "teeth", teeth)
    k.set_mats(body, k.region_mat(f"{NAME}_Body", BUSH, [("mouth", MOUTH, 0.6), ("teeth", TOOTH, 0.3)],
                                  rough=0.65, coat=0.1))

    # leaves all over (not on the face), thorns poking out, berry clusters
    for i, d in enumerate(fib(120)):
        if face_area(d):
            continue
        p, n = surface(d)
        tang = n.cross(Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))).normalized()
        k.leaf(f"{NAME}_Leaf{i}", coll, p - n * 0.08, (n * 1.0 + tang * 0.6), rnd.uniform(0.38, 0.55), 0.15,
               leaf_a if i % 3 else leaf_b, curl=0.18, fold=0.1, up=tuple(n))
    for i, d in enumerate(fib(26)):
        dd = (d + Vector((0.05, 0.03, 0.02))).normalized()
        if face_area(dd):
            continue
        p, n = surface(dd)
        ln = rnd.uniform(0.35, 0.55)
        k.blob(f"{NAME}_Thorn{i}", coll, [k.capsule(p - n * 0.05, p + n * ln * 0.35, 0.07),
                                          k.capsule(p + n * ln * 0.35, p + n * ln * 0.7, 0.045),
                                          k.capsule(p + n * ln * 0.7, p + n * ln, 0.02)], thorn, resolution=0.015)
    for i, d in enumerate(fib(9)):
        dd = (d + Vector((0.2, -0.1, 0.1))).normalized()
        if face_area(dd):
            continue
        p, n = surface(dd)
        t1 = n.cross(Vector((0, 0, 1))).normalized() if abs(n.z) < 0.9 else Vector((1, 0, 0))
        t2 = n.cross(t1)
        for j, (u, v) in enumerate(((0, 0), (0.13, 0.05), (0.04, 0.13))):
            k.sphere(f"{NAME}_Berry{i}x{j}", coll, p + n * 0.12 + t1 * u + t2 * v, 0.09, berry, segs=20, rings=12)

    # face: angry eyes and brows set into the bush
    lid = k.mat(f"{NAME}_LidSkin", BUSH_L, rough=0.6, coat=0.1)
    for s in (-1, 1):
        k.eye(NAME, coll, C + Vector((s * 0.33, -0.86, 0.15)), 0.2, look=(s * 0.06, -1, -0.05), iris="#7a3a12",
              iris_size=0.64, lid=lid, lid_close=0.36, lid_tilt=-26, side=s)
        k.blob(f"{NAME}_Brow{'L' if s > 0 else 'R'}", coll,
               [k.capsule(C + Vector((s * 0.1, -0.98, 0.38)), C + Vector((s * 0.55, -0.9, 0.52)), 0.075)],
               k.mat(f"{NAME}_Brow", BROW, rough=0.6), resolution=0.02)

    # four gnarled root legs and two bramble arms
    for i, a in enumerate((45, 135, 225, 315)):
        r = math.radians(a)
        o = Vector((math.cos(r), math.sin(r), 0))
        pts = [C + o * 0.5 + Vector((0, 0, -0.85)), C + o * 0.85 + Vector((0, 0, -1.35)),
               o * 1.05 + Vector((0, 0, 0.35)), o * 1.25 + Vector((0, 0, 0.06))]
        k.tube(f"{NAME}_Leg{i}", coll, [tuple(p) for p in pts], [0.17, 0.15, 0.13, 0.1], root)
        for j, tw in enumerate((-40, 0, 40)):
            rr = r + math.radians(tw)
            toe = o * 1.2 + Vector((math.cos(rr) * 0.35, math.sin(rr) * 0.35, 0.03))
            k.tube(f"{NAME}_Toe{i}x{j}", coll, [tuple(o * 1.18 + Vector((0, 0, 0.08))), tuple(toe)], [0.07, 0.03],
                   root)
    for s in (-1, 1):
        pts = [C + Vector((s * 1.0, -0.1, -0.1)), C + Vector((s * 1.55, -0.25, 0.1)),
               C + Vector((s * 1.85, -0.35, 0.55)), C + Vector((s * 1.9, -0.4, 0.95))]
        k.tube(f"{NAME}_Arm{'L' if s > 0 else 'R'}", coll, [tuple(p) for p in pts], [0.13, 0.11, 0.09, 0.07], root)
        for j in range(4):
            p = pts[1] + (pts[3] - pts[1]) * (j / 3)
            out = Vector((s * 0.4, -0.6 if j % 2 else 0.6, 0.7 if j % 2 else -0.3)).normalized()
            k.blob(f"{NAME}_ArmThorn{'L' if s > 0 else 'R'}{j}", coll,
                   [k.capsule(p, p + out * 0.18, 0.04), k.capsule(p + out * 0.18, p + out * 0.3, 0.015)], thorn,
                   resolution=0.015)
        for j in range(3):
            k.leaf(f"{NAME}_HandLeaf{'L' if s > 0 else 'R'}{j}", coll, tuple(pts[3]),
                   (s * (j - 1) * 0.5, -0.2, 1), 0.35, 0.12, leaf_b, curl=0.2)
    return coll
