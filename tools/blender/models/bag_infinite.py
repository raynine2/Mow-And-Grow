"""Robux bag, the Bottomless Sack: a plump deep-indigo drawstring sack spangled with glowing star patches, a gold
drawstring knot and a swirl of glowing light spilling out of its open top. About 2.6 x 2.6 x 3.4 studs."""
import math

PREVIEW = dict(dist=8.5, height=3.2, target_z=1.7, yaw=30)


def build(lib):
    sack = lib.material("Fabric", (52, 40, 110))
    sack_dark = lib.material("Fabric", (38, 28, 84))
    star = lib.material("Neon", (120, 230, 255))
    star_b = lib.material("Neon", (255, 120, 220))
    gold = lib.material("SmoothPlastic", (250, 200, 60))
    lib.sphere("belly", 1.35, (0, 0, 1.3), mat=sack, subdiv=2)
    lib.cyl("neck", 0.75, 1.0, (0, 0, 2.7), mat=sack_dark, verts=12, top_scale=1.35)
    lib.cyl("rim", 1.05, 0.25, (0, 0, 3.25), mat=sack_dark, verts=12)
    lib.cyl("tie", 0.82, 0.26, (0, 0, 2.45), mat=gold, verts=12)
    lib.box("knot", (0.4, 0.4, 0.4), (0, 0.82, 2.45), rot=(0, 45, 0), mat=gold, bevel=0.08)
    for i, sx in enumerate((-1, 1)):
        lib.box("tail%d" % i, (0.14, 0.14, 0.8), (sx * 0.18, 0.9, 2.05), rot=(0, sx * 18, 0), mat=gold)
    # glowing stars stitched on the belly: small turned cubes just poking out of the surface
    pts = [(30, 1.5), (110, 0.9), (200, 1.7), (290, 1.1), (160, 0.5), (340, 0.6), (70, 1.9)]
    for i, (a, z) in enumerate(pts):
        r = math.sqrt(max(1.35 ** 2 - (z - 1.3) ** 2, 0.2)) + 0.02
        lib.box("star%d" % i, (0.32, 0.32, 0.32), (math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r, z),
                rot=(45, 35, a), mat=star if i % 2 else star_b)
    # a swirl of light spilling out of the top
    for i in range(6):
        a = i * 60
        lib.box("swirl%d" % i, (0.22, 0.22, 0.22), (math.cos(math.radians(a)) * 0.5, math.sin(math.radians(a)) * 0.5, 3.5 + i * 0.12),
                rot=(45, 45, a), mat=star if i % 2 else star_b)
