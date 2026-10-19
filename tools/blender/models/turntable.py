"""Garage turntable: a low round diamond-plate platform (radius 5, 0.6 high) with an orange rim, a hub and bolts
round the edge, on a dark skirt."""
import math

PREVIEW = dict(dist=14, height=6, target_z=0.3, yaw=30)


def build(lib):
    plate = lib.material("DiamondPlate", (70, 70, 78))
    rim = lib.material("SmoothPlastic", (255, 150, 50))
    bolt = lib.material("Metal", (190, 190, 200))
    dark = lib.material("SmoothPlastic", (34, 34, 38))
    lib.cyl("skirt", 5.2, 0.4, (0, 0, 0.2), mat=dark, verts=28)
    lib.cyl("rim", 5.0, 0.18, (0, 0, 0.49), mat=rim, verts=28)
    lib.cyl("plate", 4.6, 0.62, (0, 0, 0.31), mat=plate, verts=28)
    lib.cyl("hub", 0.9, 0.7, (0, 0, 0.35), mat=rim, verts=12)
    for i in range(12):
        a = 2 * math.pi * i / 12
        lib.cyl("bolt%d" % i, 0.16, 0.66, (math.cos(a) * 4.8, math.sin(a) * 4.8, 0.32), mat=bolt, verts=6)
