"""Tool display for a cabin wall (Chop A Forest's "$150" axe frame): a light plank backing board (~6 x 5) with a
thin dark frame border, two pegs for the tool, and a dark price board (~5 x 1.6) under it, overlapping the bottom
edge. Flat, faces +Y; its back (-Y) goes against the wall. Bottom of the price board is at z = 0."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=11, height=4.5, target_z=3.2, yaw=20)


def build(lib):
    light = lib.material("WoodPlanks", (232, 176, 112))
    light2 = lib.material("WoodPlanks", (218, 160, 98))
    frame = lib.material("Wood", (128, 78, 44))
    dark = lib.material("Wood", (62, 42, 30))
    w, h, bz = 6.2, 5.0, 3.6          # backing size and centre height
    # backing: four horizontal planks
    kit.plank_board(lib, "back", w, h, 0.3, (0, 0, bz), (0, 0, 0), light, light2, rows=4, bevel=0.05, gap=0.07)
    # thin frame border standing proud of the planks
    t, d = 0.32, 0.5
    lib.box("frame_t", (w + t, d, t), (0, 0.05, bz + h / 2), mat=frame, bevel=0.06)
    lib.box("frame_b", (w + t, d, t), (0, 0.05, bz - h / 2), mat=frame, bevel=0.06)
    for sx in (-1, 1):
        lib.box("frame_s%d" % sx, (t, d, h + t), (sx * w / 2, 0.05, bz), mat=frame, bevel=0.06)
        # nail heads in the corners
        lib.cyl("nail%d" % sx, 0.12, 0.1, (sx * (w / 2 - 0.45), 0.2, bz - h / 2 + 0.55), rot=(90, 0, 0), mat=dark, verts=8)
    # two pegs the tool rests on
    for sx in (-1, 1):
        lib.cyl("peg%d" % sx, 0.17, 0.9, (sx * 1.6, 0.55, bz - 0.4), rot=(90, 0, 0), mat=dark, verts=8, bevel=0.04)
        lib.cyl("pegtip%d" % sx, 0.24, 0.16, (sx * 1.6, 1.0, bz - 0.4), rot=(90, 0, 0), mat=dark, verts=8)
    # dark price board under the frame, overlapping its bottom edge
    lib.box("price", (5.0, 0.4, 1.6), (0, 0.35, 0.8 + 0.0), mat=dark, bevel=0.08)
    lib.box("price_back", (4.6, 0.3, 0.8), (0, 0.0, 1.4), mat=frame)
