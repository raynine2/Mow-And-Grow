"""Lobby REWARDS stall, like Chop A Forest's: a wooden hut ~16 wide with a plank back wall, two thick side posts
and a centre post, a beam, a layered plank roof with overhang, a big blank sign board standing on the roof (text is
added in-game), and two wooden chests with gold trim overflowing with blue gem blocks in front of the two bays."""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=30, height=11, target_z=6.5, yaw=28)


def chest(lib, name, x, y, wood, wood_dark, gold, gem_a, gem_b, rnd):
    w, d, h = 3.0, 2.1, 1.9
    lib.box(name + "_body", (w, d, h), (x, y, h / 2), mat=wood, bevel=0.1)
    lib.box(name + "_rim", (w + 0.16, d + 0.16, 0.28), (x, y, h - 0.05), mat=gold, bevel=0.05)
    lib.box(name + "_foot", (w + 0.1, d + 0.1, 0.25), (x, y, 0.125), mat=gold, bevel=0.04)
    for sx in (-1, 1):
        # vertical gold bands and corner trims
        lib.box(name + "_band%d" % sx, (0.3, d + 0.12, h - 0.1), (x + sx * w * 0.28, y, h / 2), mat=gold, bevel=0.04)
        lib.box(name + "_corner%d" % sx, (0.22, d + 0.14, h), (x + sx * (w / 2 - 0.02), y, h / 2), mat=gold)
    lib.box(name + "_lock", (0.55, 0.2, 0.7), (x, y + d / 2 + 0.08, h - 0.45), mat=gold, bevel=0.05)
    lib.box(name + "_keyhole", (0.14, 0.1, 0.26), (x, y + d / 2 + 0.2, h - 0.5), mat=wood_dark)
    # open lid tipped back
    lib.box(name + "_lid", (w + 0.1, 0.45, d * 0.9), (x, y - d / 2 - 0.15, h + d * 0.42), rot=(-12, 0, 0), mat=wood, bevel=0.08)
    lib.box(name + "_lidband", (w + 0.16, 0.5, 0.25), (x, y - d / 2 - 0.05, h + d * 0.85), rot=(-12, 0, 0), mat=gold)
    # gem pile: chunky blue blocks heaped above the rim
    lib.box(name + "_gembed", (w - 0.3, d - 0.3, 0.7), (x, y, h + 0.15), mat=gem_a, bevel=0.05)
    for i in range(9):
        gx = x + rnd.uniform(-w * 0.32, w * 0.32)
        gy = y + rnd.uniform(-d * 0.25, d * 0.25)
        s = rnd.uniform(0.55, 0.85)
        lib.box("%s_gem%d" % (name, i), (s, s, s * 0.8), (gx, gy, h + 0.5 + rnd.uniform(0.0, 0.45)),
                rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), rnd.uniform(0, 90)), mat=gem_a if i % 2 else gem_b, bevel=0.05)


def build(lib):
    rnd = random.Random(7)
    post = lib.material("Wood", (168, 112, 66))
    wall = lib.material("WoodPlanks", (150, 128, 108))
    roof = lib.material("WoodPlanks", (120, 74, 48))
    board = lib.material("WoodPlanks", (96, 58, 38))
    gold = lib.material("SmoothPlastic", (240, 186, 40))
    gem_a = lib.material("SmoothPlastic", (26, 96, 230))
    gem_b = lib.material("SmoothPlastic", (70, 156, 255))
    W, H = 16.0, 9.0
    by, fy = -2.6, 1.4        # back wall / front posts
    # floor slab (low wooden deck)
    lib.box("deck", (W + 0.4, fy - by + 1.2, 0.3), (0, (by + fy) / 2, 0.15), mat=post, bevel=0.06)
    # back wall: vertical planks in two shades
    n = 10
    for i in range(n):
        x = -W / 2 + 0.6 + (W - 1.2) * (i + 0.5) / n
        lib.box("wall%d" % i, ((W - 1.2) / n - 0.06, 0.5, H - 0.3), (x, by, (H - 0.3) / 2 + 0.15), mat=wall, bevel=0.04)
    lib.box("wall_back", (W - 1.2, 0.3, H - 0.4), (0, by - 0.15, H / 2), mat=wall)
    # posts: two thick side posts front + back, a slimmer centre post
    for sx in (-1, 1):
        for y in (by, fy):
            lib.box("post%d_%d" % (sx, int(y)), (1.2, 1.2, H), (sx * (W / 2 - 0.6), y, H / 2), mat=post, bevel=0.12)
        # round log end decorations on the front posts like the reference
        kit.log_ends(lib, "knot%d" % sx, (sx * (W / 2 - 0.6), fy + 0.6, 4.6), (sx * (W / 2 - 0.6), fy + 0.75, 4.6), 0.35, post,
                     lib.material("Wood", kit.LOG_END), verts=8, ends=(False, True))
    lib.box("post_c", (0.9, 0.9, H), (0, fy - 0.2, H / 2), mat=post, bevel=0.1)
    lib.box("post_cb", (0.9, 0.6, H), (0, by + 0.3, H / 2), mat=post, bevel=0.1)
    # beams
    lib.box("beam_f", (W + 0.6, 1.0, 1.0), (0, fy, H + 0.3), mat=post, bevel=0.1)
    lib.box("beam_b", (W + 0.6, 1.0, 1.0), (0, by, H + 0.3), mat=post, bevel=0.1)
    for sx in (-1, 1):
        lib.box("beam_s%d" % sx, (1.0, fy - by, 1.0), (sx * (W / 2 - 0.6), (by + fy) / 2, H + 0.3), mat=post, bevel=0.1)
    # layered plank roof: three stepped slabs sloping to the front and to the back
    mid = (by + fy) / 2
    for sgn in (1, -1):
        for j in range(3):
            run = 3.6 - j * 1.15
            rise = 1.0
            ang = math.degrees(math.atan2(rise * 1.3, 3.6))
            lib.box("roof%d_%d" % (sgn, j), (W + 3.0 - j * 0.8, run, 0.45),
                    (0, mid + sgn * (run / 2 - 0.2 + 0.0), H + 1.05 + j * 0.42 + (3.6 - run) * 0.33 + rise * 0.3),
                    rot=(-sgn * ang, 0, 0), mat=roof if j % 2 == 0 else board, bevel=0.08)
    lib.box("ridge", (W + 1.2, 1.2, 0.6), (0, mid, H + 2.65), mat=roof, bevel=0.1)
    # big sign board standing on the ridge (blank: text is added in-game)
    sy = mid + 0.1
    lib.box("sign", (12.0, 0.6, 3.4), (0, sy, H + 4.6), mat=board, bevel=0.12)
    lib.box("sign_trim_t", (12.6, 0.8, 0.4), (0, sy, H + 6.35), mat=roof, bevel=0.08)
    lib.box("sign_trim_b", (12.6, 0.8, 0.4), (0, sy, H + 2.9), mat=roof, bevel=0.08)
    for sx in (-1, 1):
        lib.box("sign_trim_s%d" % sx, (0.45, 0.8, 3.8), (sx * 6.2, sy, H + 4.6), mat=roof, bevel=0.08)
        lib.box("sign_leg%d" % sx, (0.6, 0.6, 1.5), (sx * 4.5, sy, H + 2.5), mat=post)
    # the two reward chests, one per bay
    for i, sx in enumerate((-1, 1)):
        chest(lib, "chest%d" % i, sx * 3.9, fy + 2.0, roof, board, gold, gem_a, gem_b, rnd)
