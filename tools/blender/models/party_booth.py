"""One lobby party booth, like Chop A Forest's "THE FOREST" start pads: an open wooden frame ~14 x 14 with four log
posts, a small sloped plank roof over the back, a blank sign board across the back top (text is added in-game), a low
log rail along the sides and back, and a thin Neon cyan square outline (~12 x 12) on the ground. Open at the front."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=27, height=12, target_z=4.5, yaw=30)


def build(lib):
    wood = lib.material("Wood", (196, 132, 76))
    ends = lib.material("Wood", kit.LOG_END)
    roof = lib.material("WoodPlanks", (150, 90, 56))
    roof2 = lib.material("WoodPlanks", (128, 76, 48))
    board = lib.material("WoodPlanks", (226, 186, 136))
    trim = lib.material("Wood", (120, 74, 44))
    neon = lib.material("Neon", kit.NEON_CYAN)
    h = 6.8       # front post height
    hb = 9.6      # back post height (taller, carries the sign + roof)
    e = 6.6       # post centre offset
    for sx in (-1, 1):
        kit.log_ends(lib, "post_f%d" % sx, (sx * e, e, 0), (sx * e, e, h), 0.55, wood, ends, verts=10, ends=(False, True))
        kit.log_ends(lib, "post_b%d" % sx, (sx * e, -e, 0), (sx * e, -e, hb), 0.6, wood, ends, verts=10, ends=(False, True))
        # low log rail along the side, two courses
        for k, z in enumerate((1.3, 2.6)):
            kit.log_ends(lib, "rail_s%d_%d" % (sx, k), (sx * e, -e - 0.5, z), (sx * e, e + 0.5, z), 0.3, wood, ends, verts=8)
        # top beam along the side tying front and back posts
        kit.log(lib, "beam_s%d" % sx, (sx * e, -e, h - 0.4), (sx * e, e, h - 0.4), 0.32, trim, verts=8)
    kit.log_ends(lib, "rail_b0", (-e - 0.5, -e, 1.3), (e + 0.5, -e, 1.3), 0.3, wood, ends, verts=8)
    kit.log(lib, "beam_f", (-e - 0.6, e, h - 0.2), (e + 0.6, e, h - 0.2), 0.36, trim, verts=8)
    # sign board across the back top (blank) with a darker frame
    sz = 6.4
    kit.plank_board(lib, "sign", 10.4, 4.2, 0.4, (0, -e + 0.1, sz), (0, 0, 0), board, board, rows=3, bevel=0.05)
    lib.box("sign_t", (11.4, 0.6, 0.4), (0, -e + 0.1, sz + 2.25), mat=trim, bevel=0.06)
    lib.box("sign_b", (11.4, 0.6, 0.4), (0, -e + 0.1, sz - 2.25), mat=trim, bevel=0.06)
    # small sloped plank roof over the back: rises from the middle toward the back, with an overhang
    y0, y1 = -1.8, -e - 1.2
    z0, z1 = hb + 0.2, hb + 1.7
    run = abs(y1 - y0); ang = math.degrees(math.atan2(z1 - z0, run))
    L = math.hypot(run, z1 - z0) + 0.4
    lib.box("roof", (2 * e + 2.6, L, 0.4), (0, (y0 + y1) / 2, (z0 + z1) / 2), rot=(-ang, 0, 0), mat=roof, bevel=0.08)
    for j in range(3):
        t = (j + 0.5) / 3
        lib.box("shingle%d" % j, (2 * e + 2.7, L / 4.5, 0.16), (0, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t + 0.28),
                rot=(-ang, 0, 0), mat=roof2)
    # roof supports: a beam across the back posts and two rafters out to the middle
    lib.box("beam_b", (2 * e + 1.4, 0.7, 0.7), (0, -e, hb - 0.1), mat=trim, bevel=0.06)
    for sx in (-1, 1):
        lib.box("rafter%d" % sx, (0.5, abs(y0 + e) + 0.6, 0.5), (sx * e, (y0 - e) / 2, hb + 0.05), mat=trim, bevel=0.05)
        kit.log(lib, "strut%d" % sx, (sx * e, -1.8, hb), (sx * e, -1.8, h - 0.4), 0.28, trim, verts=8)
    # Neon cyan outline on the ground
    half, t = 6.0, 0.35
    for sy in (-1, 1):
        lib.box("neon_x%d" % sy, (2 * half + t, t, 0.12), (0, sy * half, 0.06), mat=neon)
    for sx in (-1, 1):
        lib.box("neon_y%d" % sx, (t, 2 * half - t, 0.12), (sx * half, 0, 0.06), mat=neon)
