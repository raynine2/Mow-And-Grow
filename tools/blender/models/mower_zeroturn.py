"""Golden Zero-Turn (ride-on mower): a low, shiny gold zero-turn. Big lugged rear drive tyres under gold fenders,
little front caster wheels on chrome swivel forks, an open diamond-plate footboard with a gold nose and two
headlights, a high-back black seat between gold side pods with two chrome lap-bar steering levers (no steering wheel),
a black engine with a gold cover and twin chrome exhausts at the back, and a very wide gold deck out front with black
hazard stripes, a side chute and anti-scalp rollers.

Front +Y, wheels on z = 0; the seat cushion top is flat at z = 3 around (0, -1). About 6.6 wide (7 with the chute) x
9.3 long x 5 tall."""
import math
import bmesh
from mathutils import Matrix, Vector

PREVIEW = dict(dist=16, height=9, target_z=2.0, yaw=40)


# ---- helpers (local to this file) -------------------------------------------------------------------------------
def _frame(d):
    z = d.normalized()
    up = Vector((0, 0, 1)) if abs(z.z) < 0.95 else Vector((0, 1, 0))
    x = up.cross(z).normalized()
    return Matrix((x, z.cross(x), z)).transposed()


def beam(lib, name, p0, p1, size, mat, bevel=0.05, taper=None, roll=0):
    """Box running from p0 to p1; size = (width, height) across it; taper narrows it toward p1."""
    p0, p1 = Vector(p0), Vector(p1)
    o = lib.box(name, (size[0], size[1], (p1 - p0).length), mat=mat, bevel=bevel, taper=taper)
    o.rotation_euler = (_frame(p1 - p0) @ Matrix.Rotation(math.radians(roll), 3, "Z")).to_euler()
    o.location = (p0 + p1) / 2
    return o


def wheel(lib, name, loc, r, w, tyre, hub, verts=14, hub_scale=0.55, lugs=0):
    """Wheel with its axle along X: a fat bevelled tyre, a hub disc, a centre cap, optional tread lugs."""
    x, y, z = loc
    s = 1 if x >= 0 else -1
    lib.cyl(name, r, w, loc, rot=(0, 90, 0), mat=tyre, verts=verts, bevel=min(0.12, r * 0.12))
    lib.cyl(name + "_hub", r * hub_scale, w + 0.1, loc, rot=(0, 90, 0), mat=hub, verts=10)
    lib.cyl(name + "_cap", r * 0.2, w + 0.3, loc, rot=(0, 90, 0), mat=tyre, verts=6)
    for k in range(lugs):
        a = 360.0 * k / lugs
        for side in (-1, 1):   # chevron: two angled blocks per lug
            p = Vector((x + side * w * 0.25, y + r * math.cos(math.radians(a)), z + r * math.sin(math.radians(a))))
            lug = lib.box("%s_lug%d_%d" % (name, k, side), (w * 0.5, 0.22, 0.2), p, mat=tyre)
            lug.rotation_euler = (Matrix.Rotation(math.radians(a - 90), 3, "X")
                                  @ Matrix.Rotation(math.radians(25 * side), 3, "Z")).to_euler()


def hazard(lib, name, origin, u_axis, v_axis, length, height, depth, mats, width=0.5, slant=35):
    """Flat panel of diagonal hazard stripes (alternating mats) filling length x height exactly.
    origin = bottom-left corner on the panel's back face; u along the length, v up; it grows along u x v."""
    o, u, v = Vector(origin), Vector(u_axis).normalized(), Vector(v_axis).normalized()
    n = u.cross(v)
    s = height * math.tan(math.radians(slant))
    def clip(poly, lo):
        out = []
        keep = (lambda p: p[0] >= 0) if lo else (lambda p: p[0] <= length)
        lim = 0.0 if lo else length
        for i, a in enumerate(poly):
            b = poly[(i + 1) % len(poly)]
            if keep(a):
                out.append(a)
            if keep(a) != keep(b):
                t = (lim - a[0]) / (b[0] - a[0])
                out.append((lim, a[1] + t * (b[1] - a[1])))
        return out
    i = -int(s / width) - 1
    while i * width < length:
        u0 = i * width
        poly = clip(clip([(u0, 0), (u0 + width, 0), (u0 + width + s, height), (u0 + s, height)], True), False)
        if len(poly) >= 3:
            bm = bmesh.new()
            back = [bm.verts.new(o + u * a + v * b) for a, b in poly]
            front = [bm.verts.new(o + u * a + v * b + n * depth) for a, b in poly]
            bm.faces.new(back[::-1]); bm.faces.new(front)
            for k in range(len(poly)):
                bm.faces.new((back[k], back[(k + 1) % len(poly)], front[(k + 1) % len(poly)], front[k]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            lib._from_bmesh("%s%d" % (name, i), bm).data.materials.append(mats[i % 2])
        i += 1


def steering_wheel(lib, centre, tilt, r, mat, hub_mat, column_to=None):
    """Ring of 8 beams facing the driver (at -Y), tilted `tilt` degrees from flat, with a hub and 3 spokes."""
    c = Vector(centre)
    t = math.radians(tilt)
    n = Vector((0, -math.sin(t), math.cos(t)))
    ex = Vector((1, 0, 0)); ey = n.cross(ex)
    pts = [c + r * (math.cos(k * math.pi / 4) * ex + math.sin(k * math.pi / 4) * ey) for k in range(8)]
    for k in range(8):
        a, b = pts[k], pts[(k + 1) % 8]
        beam(lib, "sw_ring%d" % k, a + (a - b) * 0.08, b + (b - a) * 0.08, (0.16, 0.16), mat, bevel=0)
    for k in (2, 5, 7):
        beam(lib, "sw_spoke%d" % k, c, pts[k], (0.1, 0.08), hub_mat, bevel=0)
    lib.cyl("sw_hub", 0.18, 0.2, c, mat=hub_mat, verts=8).rotation_euler = _frame(n).to_euler()
    if column_to:
        beam(lib, "sw_column", c - n * 0.1, column_to, (0.18, 0.18), hub_mat, bevel=0.03)


def seat(lib, cushion, back, base, y=-1.0, top=3.0, width=2.0, depth=1.7):
    """Driver seat: a flat cushion whose top is exactly at z = top around y, a tilted backrest, a pedestal."""
    lib.box("seat_cushion", (width, depth, 0.42), (0, y, top - 0.21), mat=cushion, bevel=0.14)
    beam(lib, "seat_back", (0, y - depth / 2 + 0.1, top - 0.1), (0, y - depth / 2 - 0.2, top + 1.55), (width * 0.92, 0.38),
         back, bevel=0.14, taper=(0.9, 1))
    lib.box("seat_pan", (width * 0.85, depth * 0.85, 0.3), (0, y, top - 0.55), mat=base, bevel=0.06)


def fender(lib, name, x, cy, cz, r, width, mat, arc=(5, 50, 100, 150, 178)):
    """Mudguard over a wheel (axle along X at y = cy, z = cz) from a few plates on an arc of radius r."""
    for k in range(len(arc) - 1):
        a0, a1 = math.radians(arc[k]), math.radians(arc[k + 1])
        p0 = Vector((x, cy + r * math.cos(a0), cz + r * math.sin(a0)))
        p1 = Vector((x, cy + r * math.cos(a1), cz + r * math.sin(a1)))
        beam(lib, "%s_%d" % (name, k), p0 + (p0 - p1) * 0.04, p1 + (p1 - p0) * 0.04, (width, 0.22), mat, bevel=0.07)


# ---- model ------------------------------------------------------------------------------------------------------
def build(lib):
    gold = lib.material("Metal", (255, 200, 40))   # Config colour of the Golden Zero-Turn
    black = lib.material("SmoothPlastic", (30, 30, 36))
    tyre = lib.material("Plastic", (40, 40, 44))
    chrome = lib.material("Metal", (212, 216, 224))
    plate = lib.material("DiamondPlate", (96, 98, 106))
    lamp = lib.material("Neon", (255, 248, 220))

    # big drive wheels at the back under gold fenders, small caster wheels on swivel forks at the front
    for x in (-1, 1):
        s = x > 0
        wheel(lib, "rear%d" % s, (x * 2.35, -2.3, 1.5), 1.5, 1.25, tyre, gold, verts=16, lugs=8)
        fender(lib, "fender%d" % s, x * 2.35, -2.3, 1.5, 1.75, 1.4, gold, arc=(8, 50, 95, 140, 178))
        cx, cy = x * 2.0, 1.85
        lib.cyl("caster%d" % s, 0.58, 0.55, (cx, cy, 0.58), rot=(0, 90, 0), mat=tyre, verts=12, bevel=0.07)
        lib.cyl("caster_hub%d" % s, 0.3, 0.62, (cx, cy, 0.58), rot=(0, 90, 0), mat=chrome, verts=8)
        for k in (-1, 1):
            lib.box("fork%d%d" % (s, k > 0), (0.12, 0.35, 0.95), (cx + k * 0.36, cy - 0.12, 0.92), rot=(-14, 0, 0), mat=chrome)
        lib.box("fork_top%d" % s, (0.9, 0.42, 0.18), (cx, cy - 0.25, 1.42), mat=chrome)
        lib.cyl("swivel%d" % s, 0.2, 0.35, (cx, cy - 0.25, 1.62), mat=black, verts=8)
        # frame rails: drive axle forward to the caster mounts
        beam(lib, "rail%d" % s, (x * 1.45, -2.2, 1.55), (x * 1.6, 1.6, 1.6), (0.4, 0.5), black, bevel=0.08)
        beam(lib, "rail_out%d" % s, (x * 1.6, 1.6, 1.6), (cx, cy - 0.25, 1.62), (0.42, 0.42), black, bevel=0.07)
    lib.box("front_bar", (4.3, 0.45, 0.45), (0, 1.6, 1.62), mat=black, bevel=0.08)
    lib.box("axle", (3.4, 0.45, 0.45), (0, -2.3, 1.5), mat=black)

    # low diamond-plate footboard between the rails, gold nose with headlights
    lib.box("footboard", (2.9, 1.9, 0.2), (0, 0.55, 1.62), rot=(8, 0, 0), mat=plate, bevel=0.04)
    lib.box("nose", (3.5, 0.6, 0.75), (0, 1.95, 1.85), mat=gold, bevel=0.18, taper=(0.92, 0.85))
    lib.box("nose_stripe", (0.6, 0.62, 0.08), (0, 1.95, 2.22), mat=black, bevel=0.02)
    for x in (-1, 1):
        lib.box("lamp_box%d" % (x > 0), (0.7, 0.2, 0.4), (x * 1.0, 2.24, 1.85), mat=black, bevel=0.05)
        lib.box("lamp%d" % (x > 0), (0.52, 0.1, 0.26), (x * 1.0, 2.32, 1.85), mat=lamp)

    # wide deck out front on two push arms, hazard stripes along the nose, side chute, anti-scalp rollers
    for x in (-1, 1):
        beam(lib, "deck_arm%d" % (x > 0), (x * 1.2, 1.7, 1.35), (x * 1.5, 2.9, 0.95), (0.28, 0.28), black, bevel=0.05)
    lib.box("deck", (6.2, 2.2, 0.6), (0, 3.65, 0.62), mat=gold, bevel=0.2, taper=(0.95, 0.88))
    lib.box("deck_dome", (4.0, 1.4, 0.32), (0, 3.6, 1.05), mat=gold, bevel=0.13, taper=(0.85, 0.8))
    lib.box("deck_rim", (6.4, 2.4, 0.18), (0, 3.65, 0.3), mat=black, bevel=0.05)
    hazard(lib, "deck_stripe", (2.85, 4.79, 0.42), (-1, 0, 0), (0, 0, 1), 5.7, 0.3, 0.04, (black, gold))
    for x in (-1.3, 0, 1.3):
        lib.cyl("spindle%d" % int(x * 10), 0.28, 0.2, (x, 3.6, 1.28), mat=chrome, verts=8)
    lib.box("chute", (0.9, 1.2, 0.5), (3.25, 3.5, 0.62), rot=(0, -12, -10), mat=black, bevel=0.1, taper=(0.75, 0.8))
    for x in (-1, 1):
        lib.cyl("roller%d" % (x > 0), 0.22, 0.3, (x * 2.75, 4.75, 0.24), rot=(0, 90, 0), mat=tyre, verts=8)

    # seat on a gold body between gold side pods, lap-bar steering levers
    lib.box("seat_base", (3.0, 2.6, 1.0), (0, -1.2, 2.05), mat=gold, bevel=0.22, taper=(0.95, 0.95))
    lib.box("seat_trim", (3.06, 2.66, 0.12), (0, -1.2, 1.62), mat=black, bevel=0.04)
    seat(lib, black, black, black, y=-1.0, top=3.0, width=2.0, depth=1.8)
    beam(lib, "headrest", (0, -2.18, 4.4), (0, -2.28, 5.0), (1.3, 0.4), black, bevel=0.14)
    for x in (-1, 1):
        s = x > 0
        lib.box("pod%d" % s, (0.85, 2.1, 0.95), (x * 1.6, -0.95, 2.8), mat=gold, bevel=0.22, taper=(0.85, 0.9))
        lib.box("pod_stripe%d" % s, (0.87, 0.3, 0.97), (x * 1.6, -0.3, 2.8), mat=black, bevel=0.05, taper=(0.85, 0.9))
        lib.cyl("pod_cap%d" % s, 0.2, 0.15, (x * 1.6, -1.4, 3.32), mat=chrome, verts=8)
        beam(lib, "lever%d" % s, (x * 1.55, -0.1, 3.05), (x * 1.55, 0.45, 4.05), (0.18, 0.18), chrome, bevel=0)
        beam(lib, "lever_bend%d" % s, (x * 1.55, 0.45, 4.05), (x * 1.0, 0.6, 4.1), (0.18, 0.18), chrome, bevel=0)
        beam(lib, "lever_grip%d" % s, (x * 1.0, 0.6, 4.1), (x * 0.3, 0.6, 4.1), (0.3, 0.3), black, bevel=0.08)

    # engine behind the seat with a gold cover, air filter, twin chrome exhausts, rear bumper
    lib.box("engine", (2.5, 1.5, 1.4), (0, -3.05, 2.35), mat=black, bevel=0.16)
    lib.box("engine_cover", (2.3, 1.35, 0.42), (0, -3.1, 3.2), mat=gold, bevel=0.14, taper=(0.85, 0.8))
    lib.cyl("air_filter", 0.42, 0.35, (0, -3.1, 3.55), mat=black, verts=10)
    for x in (-1, 1):
        lib.cyl("exhaust%d" % (x > 0), 0.17, 0.9, (x * 0.65, -3.9, 2.05), rot=(90, 0, 0), mat=chrome, verts=8)
    lib.box("bumper", (3.2, 0.3, 0.4), (0, -3.95, 1.45), mat=black, bevel=0.08)
    hazard(lib, "bumper_stripe", (-1.5, -4.1, 1.3), (1, 0, 0), (0, 0, 1), 3.0, 0.3, 0.04, (gold, black), width=0.4)
