"""Lobby leaderboard stand, like Chop A Forest's "CASH EARNED" board: a board ~12 wide x 14 tall on two round log
posts, a plank frame with a header plank, a dark blank face (text is added in-game) and a little plank roof."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=25, height=9, target_z=7, yaw=25)


def build(lib):
    wood = lib.material("Wood", (176, 116, 66))
    ends = lib.material("Wood", kit.LOG_END)
    frame = lib.material("WoodPlanks", (196, 140, 88))
    header = lib.material("WoodPlanks", (120, 50, 36))
    face = lib.material("SmoothPlastic", (44, 34, 30))
    roof = lib.material("WoodPlanks", (128, 78, 50))
    roof2 = lib.material("WoodPlanks", (104, 62, 40))
    px = 5.6
    for sx in (-1, 1):
        kit.log_ends(lib, "post%d" % sx, (sx * px, 0, 0), (sx * px, 0, 12.3), 0.55, wood, ends, verts=10, ends=(False, True))
        lib.box("foot%d" % sx, (1.6, 1.6, 0.4), (sx * px, 0, 0.2), mat=wood, bevel=0.08)
    # board: plank frame, header plank, dark face (inset, facing +Y)
    bw, bz0, bz1 = 10.4, 3.0, 11.6
    bc, bh = (bz0 + bz1) / 2, bz1 - bz0
    lib.box("frame", (bw + 0.8, 0.5, bh + 0.8), (0, 0, bc), mat=frame, bevel=0.12)
    lib.box("face", (bw - 0.4, 0.2, bh - 2.2), (0, 0.22, bc - 0.7), mat=face, bevel=0.04)
    lib.box("header", (bw - 0.4, 0.3, 1.3), (0, 0.22, bz1 - 0.95), mat=header, bevel=0.06)
    lib.box("back", (bw + 0.6, 0.3, bh + 0.6), (0, -0.3, bc), mat=roof2)
    # little plank roof (gable, ridge along X) on top of the posts
    lib.box("beam", (2 * px + 1.6, 1.2, 0.6), (0, 0, 12.5), mat=wood, bevel=0.08)
    ang = 34
    run = 2.4
    for sgn in (1, -1):
        y = sgn * run / 2 * math.cos(math.radians(ang)) + sgn * 0.1
        lib.box("roof%d" % sgn, (2 * px + 3.0, run + 0.5, 0.4), (0, y, 13.45), rot=(-sgn * ang, 0, 0), mat=roof, bevel=0.08)
        lib.box("shingle%d" % sgn, (2 * px + 3.1, 0.6, 0.16), (0, y + sgn * 0.55, 13.45 - 0.2), rot=(-sgn * ang, 0, 0), mat=roof2)
    lib.box("ridge", (2 * px + 3.3, 0.6, 0.5), (0, 0, 14.15), mat=roof2, bevel=0.06)
