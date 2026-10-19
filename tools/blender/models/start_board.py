"""Lobby START board: the plank sign board from start_sign raised high on two tall log legs (with braces) so it
shows over the party booths' roofs. Stands on the ground; placed at scale 1.6, where the board sits LIFT model
studs higher than on start_sign. Faces +Y; text is added in-game."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=48, height=14, target_z=11, yaw=22)
LIFT = 9 / 1.6  # the old code lifted start_sign 9 studs at scale 1.6


def build(lib):
    wood = lib.material("Wood", (168, 110, 64))
    ends = lib.material("Wood", kit.LOG_END)
    plank_a = lib.material("WoodPlanks", (122, 78, 48))
    plank_b = lib.material("WoodPlanks", (108, 68, 42))
    frame = lib.material("Wood", (82, 52, 34))
    px = 12.5
    for sx in (-1, 1):
        kit.log_ends(lib, "post%d" % sx, (sx * px, -0.7, 0), (sx * px, -0.7, 12.6 + LIFT), 0.95, wood, ends, verts=12, ends=(False, True))
        lib.box("collar%d" % sx, (2.4, 2.4, 0.5), (sx * px, -0.7, 0.25), mat=frame, bevel=0.1)
        lib.box("brace%d" % sx, (0.5, 0.5, 4.5), (sx * (px - 1.6), -0.7, 2.6), rot=(0, sx * 35, 0), mat=frame, bevel=0.06)
    w, h, zc = 29.0, 6.4, 8.4 + LIFT
    kit.plank_board(lib, "board", w, h, 0.5, (0, 0.35, zc), (0, 0, 0), plank_a, plank_b, rows=4, bevel=0.06, gap=0.1)
    t = 0.5
    lib.box("frame_t", (w + 2 * t, 0.8, t), (0, 0.35, zc + h / 2 + t / 2), mat=frame, bevel=0.1)
    lib.box("frame_b", (w + 2 * t, 0.8, t), (0, 0.35, zc - h / 2 - t / 2), mat=frame, bevel=0.1)
    for sx in (-1, 1):
        lib.box("frame_s%d" % sx, (t, 0.8, h), (sx * (w / 2 + t / 2), 0.35, zc), mat=frame, bevel=0.1)
        for z in (zc - 1.8, zc + 1.8):
            lib.cyl("bolt%d_%d" % (sx, int(z)), 0.22, 0.2, (sx * px, 0.65, z), rot=(90, 0, 0), mat=frame, verts=8)
