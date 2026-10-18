"""One lobby party booth, like Chop A Forest's "THE FOREST" start pads: an open wooden frame ~14 x 14. Two tall log
posts at the back carry a blank sign board (text is added in-game) under a small gabled plank roof; two short log
posts at the front corners; a low two-log rail along both sides and the back; and a thin Neon cyan square outline
(~12 x 12) on the ground. Open at the front (+Y)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=28, height=11, target_z=4.5, yaw=30)

E = 6.6        # post centre offset from the middle
HB = 10.2      # back post height
HF = 3.8       # front post height
SIGN = dict(centre=(0, -E + 0.45, 7.0), w=10.6, h=4.2)


def build(lib):
    wood = lib.material("Wood", (196, 132, 76))
    ends = lib.material("Wood", kit.LOG_END)
    roof = lib.material("WoodPlanks", (150, 90, 56))
    roof2 = lib.material("WoodPlanks", (124, 74, 46))
    board = lib.material("WoodPlanks", (226, 186, 136))
    trim = lib.material("Wood", (120, 74, 44))
    neon = lib.material("Neon", kit.NEON_CYAN)
    for sx in (-1, 1):
        kit.log_ends(lib, "post_f%d" % sx, (sx * E, E, 0), (sx * E, E, HF), 0.55, wood, ends, verts=10, ends=(False, True))
        kit.log_ends(lib, "post_b%d" % sx, (sx * E, -E, 0), (sx * E, -E, HB), 0.62, wood, ends, verts=10, ends=(False, True))
        # low log rail along the side, two courses
        for k, z in enumerate((1.2, 2.6)):
            kit.log_ends(lib, "rail_s%d_%d" % (sx, k), (sx * E, -E - 0.6, z), (sx * E, E + 0.6, z), 0.3, wood, ends, verts=8)
    for k, z in enumerate((1.2, 2.6)):
        kit.log_ends(lib, "rail_b%d" % k, (-E - 0.6, -E, z), (E + 0.6, -E, z), 0.3, wood, ends, verts=8)
    # sign board between the back posts (blank) with a darker frame
    cx, cy, cz = SIGN["centre"]
    sw, sh = SIGN["w"], SIGN["h"]
    kit.plank_board(lib, "sign", sw, sh, 0.4, (cx, cy, cz), (0, 0, 0), board, board, rows=3, bevel=0.05)
    lib.box("sign_t", (2 * E, 0.7, 0.5), (0, cy - 0.05, cz + sh / 2 + 0.25), mat=trim, bevel=0.06)
    lib.box("sign_b", (2 * E, 0.7, 0.5), (0, cy - 0.05, cz - sh / 2 - 0.25), mat=trim, bevel=0.06)
    # small gabled plank roof on top of the back posts (ridge along X)
    lib.box("beam", (2 * E + 2.0, 1.6, 0.6), (0, -E, HB + 0.1), mat=trim, bevel=0.08)
    ang, run = 30, 2.6
    for sgn in (1, -1):
        y = -E + sgn * (run / 2 * math.cos(math.radians(ang)) + 0.05)
        z = HB + 0.55 + run / 2 * math.sin(math.radians(ang))
        lib.box("roof%d" % sgn, (2 * E + 3.4, run + 0.6, 0.42), (0, y, z), rot=(-sgn * ang, 0, 0), mat=roof, bevel=0.08)
        lib.box("shingle%d" % sgn, (2 * E + 3.5, 0.7, 0.16), (0, y + sgn * 0.75, z - 0.25), rot=(-sgn * ang, 0, 0), mat=roof2)
    lib.box("ridge", (2 * E + 3.7, 0.6, 0.55), (0, -E, HB + 0.6 + run * math.sin(math.radians(ang))), mat=roof2, bevel=0.06)
    # Neon cyan outline on the ground
    half, t = 6.0, 0.35
    for sy in (-1, 1):
        lib.box("neon_x%d" % sy, (2 * half + t, t, 0.12), (0, sy * half, 0.06), mat=neon)
    for sx in (-1, 1):
        lib.box("neon_y%d" % sx, (t, 2 * half - t, 0.12), (sx * half, 0, 0.06), mat=neon)
