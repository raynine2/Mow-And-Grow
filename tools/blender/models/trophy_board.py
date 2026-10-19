"""BEST TIMES board (lobby): a tall dark plank board in a log frame on two log legs, with a big gold trophy cup on
top and a round stopwatch dial fixed to its top-right corner. The face (x -5..5, z 3..11.5 at y = 0.42) is blank;
the fastest runs are written on it in-game. Faces +Y."""
import math
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=26, height=9, target_z=7.5, yaw=22)


def build(lib):
    log = lib.material("Wood", (176, 124, 78))
    ends = lib.material("Wood", kit.LOG_END)
    face = lib.material("WoodPlanks", (58, 40, 30))
    face_b = lib.material("WoodPlanks", (66, 46, 34))
    gold = lib.material("SmoothPlastic", (250, 200, 50))
    gold_dark = lib.material("SmoothPlastic", (214, 158, 32))
    white = lib.material("SmoothPlastic", (245, 245, 240))
    red = lib.material("SmoothPlastic", (230, 70, 60))
    w, zc, h = 11.0, 7.4, 9.4
    kit.plank_board(lib, "face", w, h, 0.4, (0, 0.1, zc), (0, 0, 0), face, face_b, rows=5, bevel=0.05, gap=0.08)
    # log frame: two legs from the ground, a top and a bottom log
    for sx in (-1, 1):
        kit.log_ends(lib, "leg%d" % sx, (sx * (w / 2 + 0.6), 0, 0), (sx * (w / 2 + 0.6), 0, zc + h / 2 + 1.0), 0.6, log, ends, verts=10, ends=(False, True))
    kit.log_ends(lib, "top", (-w / 2 - 1.3, 0.2, zc + h / 2 + 0.3), (w / 2 + 1.3, 0.2, zc + h / 2 + 0.3), 0.5, log, ends, verts=10)
    kit.log_ends(lib, "bottom", (-w / 2 - 0.6, 0.2, zc - h / 2 - 0.3), (w / 2 + 0.6, 0.2, zc - h / 2 - 0.3), 0.45, log, ends, verts=10)
    # trophy: base, stem, cup, two handles, star on the front
    tz = zc + h / 2 + 0.8
    lib.box("tbase", (2.6, 1.6, 0.7), (0, 0.2, tz + 0.35), mat=face, bevel=0.1)
    lib.box("tplinth", (2.0, 1.2, 0.35), (0, 0.2, tz + 0.88), mat=gold_dark, bevel=0.06)
    lib.cyl("tstem", 0.28, 0.9, (0, 0.2, tz + 1.5), mat=gold, verts=10)
    lib.cyl("tcup", 1.2, 2.0, (0, 0.2, tz + 2.9), mat=gold, verts=14, top_scale=1.25, bevel=0.06)
    lib.cyl("tlip", 1.55, 0.2, (0, 0.2, tz + 3.92), mat=gold_dark, verts=14)
    for sx in (-1, 1):
        lib.box("handle%d" % sx, (0.3, 0.3, 1.5), (sx * 1.65, 0.2, tz + 3.0), rot=(0, sx * 25, 0), mat=gold_dark, bevel=0.06)
    lib.box("tstar", (0.6, 0.15, 0.6), (0, 1.5, tz + 2.9), rot=(0, 45, 0), mat=white)
    # stopwatch dial on the top right corner
    cx, cz = w / 2 - 0.4, zc + h / 2 - 0.4
    lib.cyl("dial_rim", 1.6, 0.4, (cx, 0.55, cz), rot=(90, 0, 0), mat=gold, verts=18)
    lib.cyl("dial", 1.35, 0.2, (cx, 0.72, cz), rot=(90, 0, 0), mat=white, verts=18)
    lib.cyl("crown", 0.3, 0.6, (cx, 0.55, cz + 1.85), mat=gold_dark, verts=8)
    for i in range(12):
        a = math.radians(i * 30)
        lib.box("tick%d" % i, (0.1, 0.06, 0.32 if i % 3 == 0 else 0.18), (cx + math.sin(a) * 1.1, 0.84, cz + math.cos(a) * 1.1), rot=(0, math.degrees(a), 0), mat=face)
    lib.box("hand", (0.12, 0.06, 1.0), (cx + 0.25, 0.86, cz + 0.4), rot=(0, 30, 0), mat=red)
