"""Thorn Bush, the zone 2 boss (Golf Course), ~16 tall.

A big round angry bush: a green ball body bristling with chunky leaf clumps in two greens and long cream thorns
pointing every way, dotted with red berries. It stands on four gnarled brown roots like stubby legs and swings
two thorny bramble arms. The angry face (big white eyes glaring inward under heavy slanted brows, a wide snarl full
of pointed teeth) is on the front (+Y), in the upper half of the ball.
"""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
import _bosskit as bk  # noqa: E402

PREVIEW = dict(dist=34, height=12, target_z=8, yaw=32)

C = (0, 0, 8.2)
R = (6.0, 5.3, 5.7)


def build(lib):
    rnd = random.Random(21)
    green = lib.material("Grass", (40, 140, 60))
    green_d = lib.material("Grass", (30, 112, 46))
    wood = lib.material("Wood", (112, 66, 42))
    thorn = lib.material("SmoothPlastic", (238, 222, 176))
    berry = lib.material("SmoothPlastic", (214, 38, 48))
    white = lib.material("SmoothPlastic", (248, 248, 240))
    black = lib.material("SmoothPlastic", (28, 24, 26))
    mouth_in = lib.material("SmoothPlastic", (96, 22, 30))

    # ---- body ball ---------------------------------------------------------------------------------------------
    bk.ellipsoid(lib, "body", R, C, green, segs=14, rings=9)
    surf = bk.ellip_surface(C, R)

    # leaf clumps all over, leaving the face clear, each with a thorn sticking out of it
    n = 34
    golden = math.pi * (3 - math.sqrt(5))
    k = 0
    for i in range(n):
        zf = 1 - (i + 0.5) / n * 1.75          # skip the very bottom
        rr = math.sqrt(max(0, 1 - zf * zf))
        a = i * golden
        d = bk.Vector((math.cos(a) * rr, math.sin(a) * rr, zf))
        if d.y > 0.42 and -0.75 < zf < 0.62:   # the face
            continue
        p = bk.Vector((C[0] + d.x * R[0] * 0.92, C[1] + d.y * R[1] * 0.92, C[2] + d.z * R[2] * 0.92))
        s = rnd.uniform(2.6, 3.4)
        lib.box("clump%d" % i, (s, s, s * 0.8), tuple(p), rot=(rnd.uniform(0, 90), rnd.uniform(0, 90), rnd.uniform(0, 90)),
                mat=(green, green_d)[k % 2], bevel=0.22)
        nrm = bk.Vector((d.x / R[0], d.y / R[1], d.z / R[2])).normalized()
        base = p + nrm * (s * 0.25)
        tip = base + nrm * rnd.uniform(2.1, 2.7)
        bk.cone(lib, "thorn%d" % i, tuple(base), tuple(tip), 0.55, thorn, verts=6)
        if k % 2 == 1:
            side = nrm.cross(bk.Vector((0, 0, 1))).normalized() if abs(nrm.z) < 0.95 else bk.Vector((1, 0, 0))
            lib.sphere("berry%d" % i, 0.62, tuple(p + nrm * (s * 0.45) + side * 1.0), mat=berry, subdiv=1)
        k += 1
    # small thorns framing the face
    for i, (x, z) in enumerate(((-4.6, 11.3), (4.6, 11.3), (-5.2, 7.0), (5.2, 7.0), (0, 13.4))):
        p, nrm = surf(x, z)
        bk.cone(lib, "fthorn%d" % i, tuple(p - nrm * 0.2), tuple(p + nrm * 2.2 + bk.Vector((0, 0, 0.3))), 0.45, thorn, verts=6)

    # ---- roots / legs ------------------------------------------------------------------------------------------
    for i, a in enumerate((45, 135, 225, 315)):
        r = math.radians(a)
        pts = [(math.sin(r) * 1.2, math.cos(r) * 1.2, 4.0), (math.sin(r) * 2.6, math.cos(r) * 2.6, 1.6),
               (math.sin(r) * 4.0, math.cos(r) * 4.0, 0.7)]
        bk.tube(lib, "root%d" % i, pts, [1.2, 0.95, 0.7], wood, verts=8)
        lib.box("toe%d" % i, (1.5, 2.0, 0.7), (math.sin(r) * 4.4, math.cos(r) * 4.4, 0.35), rot=(0, 0, -a), mat=wood,
                bevel=0.15, taper=(0.7, 0.6))

    # ---- bramble arms ------------------------------------------------------------------------------------------
    for side in (-1, 1):
        pts = [(side * 4.6, -0.4, 7.4), (side * 6.6, 0.4, 7.0), (side * 7.6, 1.6, 8.6), (side * 7.4, 2.6, 10.6),
               (side * 6.4, 3.2, 11.8)]
        bk.tube(lib, "arm%d" % side, pts, [0.85, 0.75, 0.62, 0.5, 0.38], green_d, verts=8)
        for j in range(1, len(pts)):
            a, b = bk.Vector(pts[j - 1]), bk.Vector(pts[j])
            m = (a + b) / 2
            out = bk.Vector((side, 0.2, 0.6 if j % 2 else -0.4)).normalized()
            bk.cone(lib, "armthorn%d_%d" % (side, j), tuple(m), tuple(m + out * 1.3), 0.26, thorn, verts=5)
        # leafy fist at the end
        lib.box("fist%d" % side, (2.0, 2.0, 1.8), (side * 6.1, 3.3, 12.1), rot=(20, 30 * side, 15), mat=green, bevel=0.22)

    # ---- face --------------------------------------------------------------------------------------------------
    for side in (-1, 1):
        bk.eye(lib, "eye%d" % side, surf, side * 1.75, 9.7, 1.25, white, black, look=(-side * 0.22, -0.12),
               brow=26, brow_mat=black, h=1.15)
    bk.mouth(lib, "mouth", surf, 6.5, 5.0, 2.3, mouth_in, white, top_teeth=6, bottom_teeth=3, frown=0.3)
