"""Log cabin shop, matched to Chop A Forest's tool shop / lobby cabins.

Walls of stacked horizontal round logs that cross at the corners with light cut ends sticking out, a stone sill,
an open door (5 wide x 7.4 tall) in the front (+Y), two front windows and one on each side (light panes, dark
frames, shutters), a gabled plank roof with shingle rows and an overhang, a covered front porch with four log
posts, a plank floor and railings, and a stone chimney. Inside floor top is at z = 0.5 and the door is clear.
About 30 wide (X), 22 deep (Y), 18 tall.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _yardkit as kit  # noqa: E402

PREVIEW = dict(dist=58, height=17, target_z=7.5, yaw=32)

R = 0.75          # log radius
D = 2 * R         # course height
BASE = 0.4        # top of the stone sill
XW = 12.6         # side-wall log centres (x = +-XW)
FY, BY = 3.0, -10.0   # front / back wall log centres
OVER = 0.85       # log overhang past the corners
DOOR = (-2.5, 2.5, 7.9)                      # x0, x1, top
FRONT_WIN = [(-9.7, -6.3), (6.3, 9.7)]       # x ranges, courses 2..4 (z 3.4..7.9)
SIDE_WIN = (-5.2, -1.8)                      # y range, side courses 2..3 (z 4.15..7.15)


def spans(lo, hi, holes):
    out = [(lo, hi)]
    for a, b in holes:
        nxt = []
        for s, e in out:
            if b <= s or a >= e:
                nxt.append((s, e)); continue
            if a > s:
                nxt.append((s, a))
            if b < e:
                nxt.append((b, e))
        out = nxt
    return out


def walls(lib, wood, ends):
    x0, x1 = -XW - OVER, XW + OVER
    # front and back walls: logs along X
    for k in range(8):
        z = BASE + R + k * D
        for wall, y in (("f", FY), ("b", BY)):
            holes = []
            if wall == "f":
                if z - R < DOOR[2]:
                    holes.append((DOOR[0], DOOR[1]))
                if 2 <= k <= 4:
                    holes += FRONT_WIN
            for i, (s, e) in enumerate(spans(x0, x1, holes)):
                kit.log_ends(lib, "log%s%d_%d" % (wall, k, i), (s, y, z), (e, y, z), R, wood, ends, verts=8,
                             ends=(abs(s - x0) < 1e-6, abs(e - x1) < 1e-6))
    # side walls: logs along Y, half a course higher so the corners interlock
    y0, y1 = BY - OVER, FY + OVER
    for k in range(7):
        z = BASE + D + k * D
        for sx in (-1, 1):
            holes = [SIDE_WIN] if 2 <= k <= 3 else []
            for i, (s, e) in enumerate(spans(y0, y1, holes)):
                kit.log_ends(lib, "logs%d%d_%d" % (sx, k, i), (sx * XW, s, z), (sx * XW, e, z), R, wood, ends, verts=8,
                             ends=(abs(s - y0) < 1e-6, abs(e - y1) < 1e-6))
        # sill log under the first side course
    for sx in (-1, 1):
        lib.box("sidesill%d" % sx, (D * 0.9, FY - BY, R + 0.05), (sx * XW, (FY + BY) / 2, BASE + R / 2), mat=wood)


def window(lib, name, loc, rot, w, h, glass, trim):
    """Window in a local frame facing +Y: pane, frame, cross mullions, a sill and two shutters."""
    parts = [
        lib.box(name + "_glass", (w, 0.12, h), (0, 0, 0), mat=glass),
        lib.box(name + "_top", (w + 0.6, 0.5, 0.35), (0, 0.2, h / 2 + 0.1), mat=trim),
        lib.box(name + "_sill", (w + 0.8, 0.8, 0.3), (0, 0.35, -h / 2 - 0.1), mat=trim),
        lib.box(name + "_mv", (0.18, 0.3, h), (0, 0.05, 0), mat=trim),
        lib.box(name + "_mh", (w, 0.3, 0.18), (0, 0.05, 0.1), mat=trim),
    ]
    for sx in (-1, 1):
        parts.append(lib.box(name + "_jamb%d" % sx, (0.3, 1.6, h + 0.2), (sx * (w / 2 + 0.05), 0, 0), mat=trim))
        parts.append(lib.box(name + "_shutter%d" % sx, (w * 0.45, 0.22, h + 0.2), (sx * (w / 2 + w * 0.225 + 0.25), R + 0.08, 0),
                             mat=trim))
    for p in parts:
        kit.place(p, loc, rot)


def build(lib):
    wood = lib.material("Wood", kit.LOG)
    ends = lib.material("Wood", kit.LOG_END)
    roof = lib.material("WoodPlanks", kit.ROOF)
    trim = lib.material("WoodPlanks", kit.ROOF_DARK)
    floor = lib.material("WoodPlanks", (170, 116, 72))
    stone = lib.material("Slate", (140, 132, 120))
    glass = lib.material("Glass", (170, 210, 235))

    # ---- stone sill and floors ------------------------------------------------------------------------------
    lib.box("sill", (2 * XW + 2.2, FY - BY + 2.0, BASE), (0, (FY + BY) / 2, BASE / 2), mat=stone, bevel=0.08)
    lib.box("floor", (2 * XW - 0.6, FY - BY - 0.4, 0.5), (0, (FY + BY) / 2, 0.25), mat=floor)
    walls(lib, wood, ends)

    # ---- door frame (opening stays clear) -------------------------------------------------------------------
    for sx in (-1, 1):
        lib.box("doorpost%d" % sx, (0.5, 1.9, DOOR[2] - 0.4), (sx * (DOOR[1] + 0.2), FY, (DOOR[2] + 0.4) / 2), mat=trim, bevel=0.06)
    lib.box("lintel", (DOOR[1] - DOOR[0] + 1.6, 1.9, 0.5), (0, FY, DOOR[2] + 0.1), mat=trim, bevel=0.06)
    lib.box("threshold", (DOOR[1] - DOOR[0], 1.6, 0.5), (0, FY, 0.25), mat=floor)

    # ---- windows ---------------------------------------------------------------------------------------------
    for i, (a, b) in enumerate(FRONT_WIN):
        window(lib, "fwin%d" % i, ((a + b) / 2, FY, 5.65), (0, 0, 0), b - a - 0.2, 4.3, glass, trim)
    for sx in (-1, 1):
        window(lib, "swin%d" % sx, (sx * XW, sum(SIDE_WIN) / 2, 5.65), (0, 0, -90 * sx), SIDE_WIN[1] - SIDE_WIN[0] - 0.2, 2.8, glass, trim)

    # ---- gables + main roof (ridge along X) -------------------------------------------------------------------
    top = BASE + 8 * D            # 12.4
    mid = (FY + BY) / 2
    run = (FY - BY) / 2 + 1.6     # with overhang
    rise = 5.0
    import math
    ang = math.degrees(math.atan2(rise, run))
    for sx in (-1, 1):
        g = kit.prism(lib, "gable%d" % sx, [(BY - mid - R, 0), (FY - mid + R, 0), (0, rise * (FY - mid + R) / run)],
                      1.2, mat=wood)
        kit.place(g, (sx * XW, mid, top - 0.75), (0, 0, 90))
        lib.box("gable_beam%d" % sx, (0.5, 0.5, rise - 0.6), (sx * (XW + 0.7), mid, top + (rise - 0.6) / 2 - 0.3), mat=trim)
    slope_len = math.hypot(run, rise) + 0.3
    half_w = XW + 2.6
    eave_z = top - 0.7
    for side, sgn in (("f", 1), ("b", -1)):
        cy = mid + sgn * run / 2
        cz = eave_z + rise / 2 + 0.25
        lib.box("roof_" + side, (2 * half_w, slope_len, 0.5), (0, cy, cz), rot=(-sgn * ang, 0, 0), mat=roof, bevel=0.1)
        # shingle rows: thin stepped strips across the slope
        for j in range(6):
            t = (j + 0.5) / 6
            y = mid + sgn * (run * (1 - t))
            z = eave_z + rise * t + 0.25 + 0.3
            lib.box("shingle_%s%d" % (side, j), (2 * half_w + 0.1, slope_len / 7.5, 0.18), (0, y + sgn * 0.0, z),
                    rot=(-sgn * ang, 0, 0), mat=trim if j % 2 else roof)
        # fascia board at the eave
        lib.box("fascia_" + side, (2 * half_w + 0.2, 0.35, 0.8), (0, mid + sgn * (run + 0.1), eave_z - 0.1), mat=trim, bevel=0.06)
    lib.box("ridge", (2 * half_w + 0.4, 1.1, 1.1), (0, mid, eave_z + rise + 0.6), rot=(45, 0, 0), mat=trim, bevel=0.08)

    # ---- porch -----------------------------------------------------------------------------------------------
    py0, py1 = FY + R, 10.4
    lib.box("porch", (2 * XW + 1.6, py1 - py0 + 0.2, 0.5), (0, (py0 + py1) / 2, 0.25), mat=floor, bevel=0.06)
    lib.box("porch_edge", (2 * XW + 1.8, 0.45, 0.6), (0, py1 + 0.05, 0.3), mat=trim, bevel=0.06)
    lib.box("step", (6.4, 1.2, 0.25), (0, py1 + 0.85, 0.125), mat=floor, bevel=0.05)
    post_y = py1 - 0.5
    post_top = 8.6
    for i, x in enumerate((-XW, -4.0, 4.0, XW)):
        kit.log(lib, "post%d" % i, (x, post_y, 0.5), (x, post_y, post_top), 0.45, wood, verts=8)
    lib.box("porch_beam", (2 * XW + 2.0, 0.8, 0.7), (0, post_y, post_top + 0.2), mat=trim, bevel=0.08)
    p_run = post_y + 1.6 - FY
    p_drop = 1.9
    p_ang = math.degrees(math.atan2(p_drop, p_run))
    p_len = math.hypot(p_run, p_drop) + 0.4
    lib.box("porch_roof", (2 * XW + 3.0, p_len, 0.45), (0, FY + p_run / 2 - 0.1, post_top + 0.55 + p_drop / 2),
            rot=(-p_ang, 0, 0), mat=roof, bevel=0.08)
    for j in range(3):
        t = (j + 0.5) / 3
        lib.box("pshingle%d" % j, (2 * XW + 3.1, p_len / 5, 0.16),
                (0, FY + p_run * t, post_top + 0.55 + p_drop * (1 - t) + 0.3), rot=(-p_ang, 0, 0), mat=trim)
    # railings: top rail + balusters between the outer posts, and along the porch sides
    for sx in (-1, 1):
        xa, xb = sx * XW, sx * 4.0
        lib.box("rail%d" % sx, (abs(xb - xa), 0.35, 0.35), ((xa + xb) / 2, post_y, 3.3), mat=trim)
        lib.box("rail_lo%d" % sx, (abs(xb - xa), 0.3, 0.3), ((xa + xb) / 2, post_y, 1.1), mat=trim)
        for j in range(1, 8):
            x = xa + (xb - xa) * j / 8
            lib.box("bal%d_%d" % (sx, j), (0.3, 0.25, 2.2), (x, post_y, 2.2), mat=trim)
        lib.box("srail%d" % sx, (0.35, post_y - FY - 0.8, 0.35), (sx * XW, (post_y + FY + 0.8) / 2, 3.3), mat=trim)
        for j in range(1, 4):
            y = FY + 0.8 + (post_y - FY - 0.8) * j / 4
            lib.box("sbal%d_%d" % (sx, j), (0.25, 0.3, 2.2), (sx * XW, y, 2.2), mat=trim)

    # ---- stone chimney on the -X side ------------------------------------------------------------------------
    cx = -XW - 1.75
    lib.box("chimney", (2.2, 2.6, 17.4), (cx, -8.0, 8.7), mat=stone, bevel=0.12, taper=(0.9, 0.9))
    lib.box("chimney_cap", (2.6, 3.0, 0.5), (cx, -8.0, 17.55), mat=stone, bevel=0.1)
