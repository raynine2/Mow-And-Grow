"""Swamp Vine (boss 4): a murky purple vine creature. Four thick vines twist up out of a mud mound with reeds and
braid into a bulb-shaped purple head with paler spots, a crest of dark thorn leaves, glowing green eyes under
heavy brows and a jagged grin. Two tendril arms curl out from the sides of the head and swamp moss drips from its
chin. Toy scale; the game scales it up."""
import math
import random

from mathutils import Vector

NAME = "SwampVine"
HEIGHT = 4.6
VINE, VINE_D, HEAD, SPOT = "#7a4fa0", "#563a7a", "#8a5cb8", "#a982d2"
MUD, REED, MOSS, LEAF = "#4a3a2a", "#5a8a3a", "#7c9a48", "#4f7a34"
MOUTH, FANG, BROW, GLOW = "#2a1430", "#efe8cf", "#3a2450", "#9dff5a"

HEAD_C = Vector((0.0, 0.0, 3.2))
HEAD_R = (0.86, 0.74, 0.8)


def grin_z(x):
    return -0.3 + 0.1 * (x / 0.45) ** 2   # a wide grin: corners up


def mouth(c):
    if c.y > -0.2:
        return -1.0
    return 1.0 - ((c.x / 0.46) ** 4 + ((c.z - grin_z(c.x)) / 0.14) ** 2)


def fangs(c):
    m = mouth(c)
    if m < 0:
        return -1.0
    # zig-zag teeth: triangles hanging from the top edge and rising from the bottom edge
    ph = ((c.x + 0.46) % 0.13) / 0.13
    tri = 1 - abs(ph - 0.5) * 2                      # 0 at the gaps, 1 mid-tooth
    top_edge = grin_z(c.x) + 0.12
    bot_edge = grin_z(c.x) - 0.12
    upper = 0.13 * tri - (top_edge - c.z)
    ph2 = ((c.x + 0.46 + 0.065) % 0.13) / 0.13
    tri2 = 1 - abs(ph2 - 0.5) * 2
    lower = 0.1 * tri2 - (c.z - bot_edge)
    return min(m, max(upper, lower))


def spots(c):
    best = -1.0
    for sx, sy, sz, r in ((0.55, 0.3, 0.45, 0.16), (-0.6, 0.35, 0.35, 0.13), (0.2, 0.55, 0.6, 0.12),
                          (-0.35, 0.6, -0.3, 0.14), (0.7, -0.1, -0.2, 0.1), (-0.15, 0.7, 0.1, 0.11)):
        best = max(best, r - (c - Vector((sx, sy, sz))).length)
    return best


def build(k):
    rnd = random.Random(7)
    coll = k.new_scene(NAME)
    vine = k.mat(f"{NAME}_Vine", VINE, rough=0.45, coat=0.3)
    vine_d = k.mat(f"{NAME}_VineDark", VINE_D, rough=0.45, coat=0.3)
    leaf = k.mat(f"{NAME}_Leaf", LEAF, rough=0.6, coat=0.1)
    moss = k.mat(f"{NAME}_Moss", MOSS, rough=0.9, sheen=0.4, bump="fabric", bump_scale=70, bump_strength=0.2)
    reed = k.mat(f"{NAME}_Reed", REED, rough=0.6)

    mud = k.blob(f"{NAME}_Mud", coll, [dict(co=(0, 0, 0), size=(0.85, 0.8, 0.22)),
                                       dict(co=(-0.35, 0.25, 0.02), size=(0.45, 0.4, 0.16)),
                                       dict(co=(0.4, -0.2, 0.0), size=(0.35, 0.35, 0.12))],
                 k.mat(f"{NAME}_Mud", MUD, rough=0.35, coat=0.4, bump="pores", bump_scale=18, bump_strength=0.3))
    k.trim(mud, (0, 0, 0), (0, 0, -1), cap=True)
    for i in range(9):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.5, 0.8)
        base = (math.cos(a) * r, math.sin(a) * r, 0.1)
        k.leaf(f"{NAME}_Reed{i}", coll, base, (math.cos(a) * 0.2, math.sin(a) * 0.2, 1), rnd.uniform(0.6, 1.0),
               0.05, reed, curl=0.15, fold=0.03)

    # four vines braiding up: helix paths that tighten as they rise into the head
    for v in range(4):
        pts, radii = [], []
        for i in range(7):
            t = i / 6
            a = v * math.pi / 2 + t * math.pi * 1.3
            r = 0.5 * (1 - t) + 0.12
            pts.append((math.cos(a) * r, math.sin(a) * r, 0.05 + t * 2.75))
            radii.append(0.17 - 0.05 * t)
        k.tube(f"{NAME}_Vine{v}", coll, pts, radii, vine if v % 2 else vine_d)
        p = Vector(pts[3])
        out = Vector((p.x, p.y, 0)).normalized()
        k.leaf(f"{NAME}_VLeaf{v}", coll, p + out * 0.1, out + Vector((0, 0, 0.5)), 0.5, 0.14, leaf, curl=0.25)

    # bulb head: a ball drawn up into an onion tip, spotted, with a jagged glowing grin
    head = k.quadsphere(f"{NAME}_Head", coll, HEAD_C, HEAD_R, cuts=56)
    k.push(head, (0, 0, 0.85), 0.6, 0.35, direction=(0, 0, 1))
    for s in (-1, 1):
        k.push(head, (s * 0.32, -0.62, 0.18), 0.28, -0.05)          # eye sockets
    k.push(head, (0, -0.7, -0.3), 0.4, -0.04)
    k.subdivide(head, 1)
    k.apply_modifiers(head)
    k.sdf_attr(head, "spots", spots)
    k.sdf_attr(head, "mouth", mouth)
    k.sdf_attr(head, "fangs", fangs)
    k.set_mats(head, k.region_mat(f"{NAME}_Head", HEAD, [("spots", SPOT, 0.5), ("mouth", MOUTH, 0.6),
                                                         ("fangs", FANG, 0.35)], rough=0.45, coat=0.3))
    head_skin = k.mat(f"{NAME}_Lid", VINE_D, rough=0.45, coat=0.3)
    for s in (-1, 1):
        k.eye(NAME, coll, HEAD_C + Vector((s * 0.31, -0.58, 0.18)), 0.19, look=(s * 0.06, -1, -0.05),
              iris=GLOW, iris_size=0.75, glow=2.5, lid=head_skin, lid_close=0.32, lid_tilt=-26, side=s,
              white="#1d1426")
        k.blob(f"{NAME}_Brow{'L' if s > 0 else 'R'}", coll,
               [k.capsule(HEAD_C + Vector((s * 0.1, -0.72, 0.38)), HEAD_C + Vector((s * 0.52, -0.6, 0.5)), 0.07)],
               k.mat(f"{NAME}_Brow", BROW, rough=0.5, coat=0.2), resolution=0.02)

    # crest of dark thorn leaves along the top and back
    for i in range(7):
        t = (i - 3) / 3
        base = HEAD_C + Vector((t * 0.35, 0.25 + abs(t) * 0.1, 0.85 - abs(t) * 0.2))
        k.leaf(f"{NAME}_Crest{i}", coll, base, (t * 0.5, 0.6, 1.0), 0.7 - abs(t) * 0.2, 0.1, vine_d,
               curl=-0.3, fold=0.08, up=(0, -1, 0))

    # tendril arms: out from the sides of the head, down, then a curl at the end
    for s in (-1, 1):
        pts = [(s * 0.75, 0.05, 3.0), (s * 1.25, -0.05, 2.9), (s * 1.6, -0.1, 2.5), (s * 1.65, -0.12, 2.05),
               (s * 1.45, -0.12, 1.85), (s * 1.35, -0.1, 2.05)]
        k.tube(f"{NAME}_Arm{'L' if s > 0 else 'R'}", coll, pts, [0.13, 0.11, 0.09, 0.07, 0.05, 0.035], vine)
        k.leaf(f"{NAME}_ArmLeaf{'L' if s > 0 else 'R'}", coll, (s * 1.3, -0.05, 2.95), (s * 0.4, -0.2, 1),
               0.45, 0.13, leaf, curl=0.2)

    # moss dripping off the chin
    for i in range(7):
        x = -0.45 + i * 0.15
        top = HEAD_C + Vector((x, -0.35 + abs(x) * 0.3, -0.7 + abs(x) * 0.25))
        ln = rnd.uniform(0.35, 0.65)
        k.tube(f"{NAME}_Moss{i}", coll, [tuple(top), tuple(top + Vector((0.02, -0.03, -ln * 0.5))),
                                         tuple(top + Vector((-0.02, -0.02, -ln)))], [0.07, 0.05, 0.035], moss)
    return coll
