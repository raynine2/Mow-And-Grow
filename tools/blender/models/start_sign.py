"""Big lobby sign (Chop A Forest's "START A RUN" board): a wide plank board ~30 x 7 on two thick log posts, with a
darker frame and a blank face (text is added in-game). Faces +Y."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=40, height=10, target_z=7.5, yaw=22)


def build(lib):
    wood = lib.material("Wood", (168, 110, 64))
    ends = lib.material("Wood", kit.LOG_END)
    plank_a = lib.material("WoodPlanks", (122, 78, 48))
    plank_b = lib.material("WoodPlanks", (108, 68, 42))
    frame = lib.material("Wood", (82, 52, 34))
    px = 12.5
    for sx in (-1, 1):
        kit.log_ends(lib, "post%d" % sx, (sx * px, -0.7, 0), (sx * px, -0.7, 12.6), 0.95, wood, ends, verts=12, ends=(False, True))
        lib.box("collar%d" % sx, (2.4, 2.4, 0.5), (sx * px, -0.7, 0.25), mat=frame, bevel=0.1)
    # board: four planks + frame, centred at z = 8
    w, h, zc = 29.0, 6.4, 8.4
    kit.plank_board(lib, "board", w, h, 0.5, (0, 0.35, zc), (0, 0, 0), plank_a, plank_b, rows=4, bevel=0.06, gap=0.1)
    t = 0.5
    lib.box("frame_t", (w + 2 * t, 0.8, t), (0, 0.35, zc + h / 2 + t / 2), mat=frame, bevel=0.1)
    lib.box("frame_b", (w + 2 * t, 0.8, t), (0, 0.35, zc - h / 2 - t / 2), mat=frame, bevel=0.1)
    for sx in (-1, 1):
        lib.box("frame_s%d" % sx, (t, 0.8, h), (sx * (w / 2 + t / 2), 0.35, zc), mat=frame, bevel=0.1)
        # bolts holding the board to the posts
        for z in (zc - 1.8, zc + 1.8):
            lib.cyl("bolt%d_%d" % (sx, int(z)), 0.22, 0.2, (sx * px, 0.65, z), rot=(90, 0, 0), mat=frame, verts=8)
