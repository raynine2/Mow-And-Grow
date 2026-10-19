"""Zone gate, low-part version: a log palisade ~100 studs wide (X) and ~12 tall. Upright round logs in two wood
shades with uneven heights, each topped with a diamond-cut point; two cross beams on the front (+Y) and a sign board
hanging from the upper beam on two ropes. The sign's front face is at y = 2.3, centred at z = 5.3 (the game writes
"LOCKED ..." on a 15.6 x 4 panel there). About 70 parts."""
PREVIEW = dict(dist=52, height=14, target_z=6, yaw=18)


def build(lib):
    log_a = lib.material("Wood", (125, 80, 50))
    log_b = lib.material("Wood", (110, 70, 44))
    tip = lib.material("Wood", (96, 60, 38))
    beam = lib.material("WoodPlanks", (94, 60, 38))
    sign = lib.material("WoodPlanks", (200, 160, 105))
    rope = lib.material("Fabric", (180, 150, 100))
    n = 33
    for i in range(n):
        x = -49.5 + i * 3.09
        h = 11 + ((i * 7) % 3) * 0.8
        lib.cyl("log%d" % i, 1.45, h, (x, 0, h / 2), mat=log_a if i % 2 else log_b, verts=10)
        # a box turned 45 degrees round Y reads as a sharpened point
        lib.box("tip%d" % i, (1.9, 2.6, 1.9), (x, 0, h + 0.1), rot=(0, 45, 0), mat=tip)
    for i, z in enumerate((3.5, 8.5)):
        lib.box("beam%d" % i, (100, 0.6, 1.1), (0, 1.75, z), mat=beam)
    lib.box("sign", (16.4, 0.4, 4.6), (0, 2.1, 5.3), mat=sign)
    for i, x in enumerate((-6.5, 6.5)):
        lib.box("rope%d" % i, (0.18, 0.18, 1.3), (x, 2.0, 8.2), mat=rope)
