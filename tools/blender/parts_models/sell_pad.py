"""The sell pad ("drop bundles"), low-part version: a low square plank platform (~12 x 12, top at 0.82) in two plank
shades, framed by four round logs whose ends cross and stick out at the corners (with light cut ends), and a
black/yellow hazard border of alternating blocks along the inside of the frame. About 45 parts."""
PREVIEW = dict(dist=21, height=11, target_z=0.3, yaw=30)


def build(lib):
    base = lib.material("Wood", (120, 82, 52))
    plank_a = lib.material("WoodPlanks", (196, 140, 88))
    plank_b = lib.material("WoodPlanks", (178, 124, 76))
    log = lib.material("Wood", (176, 124, 78))
    end = lib.material("Wood", (222, 188, 140))
    yellow = lib.material("SmoothPlastic", (250, 206, 30))
    black = lib.material("SmoothPlastic", (30, 30, 34))
    lib.box("base", (11.6, 11.6, 0.6), (0, 0, 0.3), mat=base)
    for i in range(6):
        y = -4.6 + i * 1.84
        lib.box("plank%d" % i, (9.2, 1.76, 0.2), (0, y, 0.72), mat=plank_a if i % 2 else plank_b)
    # log frame: two along X, two along Y, ends sticking out past each other at the corners
    for i, y in enumerate((-5.9, 5.9)):
        lib.cyl("logx%d" % i, 0.55, 13.4, (0, y, 0.55), rot=(0, 90, 0), mat=log, verts=10)
        for j, x in enumerate((-6.72, 6.72)):
            lib.cyl("endx%d_%d" % (i, j), 0.47, 0.06, (x, y, 0.55), rot=(0, 90, 0), mat=end, verts=10)
    for i, x in enumerate((-5.9, 5.9)):
        lib.cyl("logy%d" % i, 0.55, 13.4, (x, 0, 0.75), rot=(90, 0, 0), mat=log, verts=10)
        for j, y in enumerate((-6.72, 6.72)):
            lib.cyl("endy%d_%d" % (i, j), 0.47, 0.06, (x, y, 0.75), rot=(90, 0, 0), mat=end, verts=10)
    # hazard border: alternating blocks along the inside of the frame
    k = 0
    for side in range(4):
        for s in range(6):
            t = -4.25 + s * 1.7
            x, y, w, d = (t, -5.0, 1.7, 0.7) if side == 0 else (t, 5.0, 1.7, 0.7) if side == 1 else (-5.0, t, 0.7, 1.7) if side == 2 else (5.0, t, 0.7, 1.7)
            lib.box("haz%d" % k, (w, d, 0.24), (x, y, 0.74), mat=yellow if (s + side) % 2 == 0 else black)
            k += 1
