"""Chunky old-style fuel pump for the mower garage: red bevelled body on a small concrete base, white top band with a
red cap, a dark screen and keypad on the front (+Y), and a hose looping down from the +X side to a nozzle that hangs
in a holder. About 6 tall."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=12, height=5, target_z=3.0, yaw=40)


def build(lib):
    red = lib.material("SmoothPlastic", (214, 38, 32))
    white = lib.material("SmoothPlastic", (240, 238, 232))
    dark = lib.material("SmoothPlastic", (34, 34, 38))
    screen = lib.material("Neon", (120, 220, 150))
    metal = lib.material("Metal", (160, 162, 168))
    concrete = lib.material("Concrete", (176, 172, 164))
    lib.box("base", (3.6, 2.8, 0.4), (0, 0, 0.2), mat=concrete, bevel=0.08)
    lib.box("plinth", (2.6, 1.8, 0.35), (0, 0, 0.57), mat=dark, bevel=0.06)
    lib.box("body", (2.3, 1.55, 4.2), (0, 0, 2.85), mat=red, bevel=0.2)
    lib.box("band", (2.45, 1.7, 0.8), (0, 0, 5.3), mat=white, bevel=0.15)
    lib.box("cap", (2.3, 1.55, 0.4), (0, 0, 5.85), mat=red, bevel=0.15)
    lib.box("cap_top", (1.4, 1.0, 0.3), (0, 0, 6.15), mat=red, bevel=0.1)
    # front: dark screen with a glowing readout, keypad, white label stripe
    fy = 0.78
    lib.box("screen", (1.7, 0.12, 1.1), (0, fy, 4.15), mat=dark, bevel=0.05)
    lib.box("readout", (1.3, 0.1, 0.32), (0, fy + 0.05, 4.32), mat=screen)
    lib.box("readout2", (0.8, 0.1, 0.22), (-0.25, fy + 0.05, 3.9), mat=screen)
    lib.box("keypad", (0.9, 0.12, 0.8), (0, fy, 3.0), mat=dark, bevel=0.04)
    for i in range(3):
        for j in range(2):
            lib.box("key%d%d" % (i, j), (0.18, 0.08, 0.18), (-0.25 + i * 0.25, fy + 0.08, 2.85 + j * 0.3), mat=metal)
    lib.box("stripe", (2.32, 1.57, 0.25), (0, 0, 1.6), mat=white)
    # nozzle holder on the +X side, nozzle hanging in it
    sx = 1.15
    lib.box("holder", (0.35, 0.8, 0.9), (sx + 0.17, 0.2, 3.6), mat=dark, bevel=0.05)
    lib.box("nozzle_grip", (0.35, 0.45, 1.0), (sx + 0.5, 0.2, 3.55), rot=(15, 0, 0), mat=dark, bevel=0.08)
    lib.box("nozzle_body", (0.4, 0.9, 0.45), (sx + 0.5, 0.55, 4.05), mat=dark, bevel=0.08)
    kit.log(lib, "spout", (sx + 0.5, 0.95, 4.05), (sx + 0.5, 1.5, 3.75), 0.11, metal, verts=8)
    lib.box("trigger_guard", (0.12, 0.6, 0.12), (sx + 0.5, 0.45, 3.65), mat=metal)
    # hose: from the side of the body low down, loops toward the ground and back up into the grip
    pts = [(sx, -0.3, 2.4), (sx + 0.35, -0.35, 1.7), (sx + 0.55, -0.15, 1.15), (sx + 0.65, 0.2, 1.05),
           (sx + 0.65, 0.45, 1.4), (sx + 0.55, 0.35, 2.2), (sx + 0.5, 0.15, 3.05)]
    for i in range(len(pts) - 1):
        kit.log(lib, "hose%d" % i, pts[i], pts[i + 1], 0.13, dark, verts=8)
    lib.box("hose_port", (0.3, 0.5, 0.5), (sx + 0.05, -0.3, 2.45), mat=metal, bevel=0.05)
